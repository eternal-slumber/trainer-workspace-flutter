import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiError implements Exception {
  const ApiError(this.message, {this.statusCode, this.errors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, String> errors;

  @override
  String toString() => message;
}

const _invalidResponse = ApiError(
  'Ответ сервера не соответствует контракту API.',
);

class HealthResponse {
  const HealthResponse(this.apiVersion);

  final String apiVersion;

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'ok' || json['api_version'] is! String) {
      throw _invalidResponse;
    }
    if (json['api_version'] != '1') {
      throw const ApiError('Версия API сервера не поддерживается приложением.');
    }
    return HealthResponse(json['api_version'] as String);
  }
}

class UserDto {
  const UserDto({
    required this.id,
    required this.name,
    required this.email,
    this.workingDayStartsAt,
    this.workingDayEndsAt,
    this.timezone,
  });

  final int id;
  final String name;
  final String email;
  final String? workingDayStartsAt;
  final String? workingDayEndsAt;
  final String? timezone;

  factory UserDto.fromJson(Map<String, dynamic> json, {bool full = false}) {
    final id = json['id'];
    final name = json['name'];
    final email = json['email'];
    if (id is! int ||
        id <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        email is! String ||
        email.trim().isEmpty) {
      throw _invalidResponse;
    }
    final start = json['working_day_starts_at'];
    final end = json['working_day_ends_at'];
    final zone = json['timezone'];
    final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$');
    if (full &&
        (start is! String ||
            !time.hasMatch(start) ||
            end is! String ||
            !time.hasMatch(end) ||
            zone is! String ||
            zone.trim().isEmpty)) {
      throw _invalidResponse;
    }
    return UserDto(
      id: id,
      name: name,
      email: email,
      workingDayStartsAt: start is String ? start : null,
      workingDayEndsAt: end is String ? end : null,
      timezone: zone is String ? zone : null,
    );
  }
}

class TokenData {
  const TokenData(this.token, this.user);

  final String token;
  final UserDto user;

  factory TokenData.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final user = json['user'];
    if (token is! String ||
        token.trim().isEmpty ||
        token.contains(RegExp(r'[\r\n]')) ||
        json['token_type'] != 'Bearer' ||
        user is! Map<String, dynamic>) {
      throw _invalidResponse;
    }
    return TokenData(token, UserDto.fromJson(user));
  }
}

class ApiClient {
  ApiClient(
    this.baseUri, {
    this.onUnauthorized,
    this.responseTimeout = const Duration(seconds: 30),
  });

  final Uri baseUri;
  final void Function(String token)? onUnauthorized;
  final Duration responseTimeout;
  HttpClient? _client;
  bool _closed = false;

  static Uri parseBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/api/mobile/v1/') {
      throw const ApiError(
        'Укажите адрес вида https://сервер/api/mobile/v1/ без логина и параметров.',
      );
    }
    final localHttp =
        kDebugMode &&
        uri.scheme == 'http' &&
        const ['10.0.2.2', '127.0.0.1', 'localhost', '::1'].contains(uri.host);
    if (uri.scheme != 'https' && !localHttp) {
      throw const ApiError(
        'Нужен HTTPS. В debug HTTP разрешён только для локального сервера эмулятора.',
      );
    }
    return uri;
  }

  Future<HealthResponse> health() async =>
      HealthResponse.fromJson(await _request('GET', 'health'));

  Future<TokenData> issueToken(String email, String password) async =>
      TokenData.fromJson(
        await _request(
          'POST',
          'auth/token',
          body: {
            'email': email.trim(),
            'password': password,
            'device_name': 'TrainerWorkspace (${Platform.operatingSystem})',
          },
        ),
      );

  Future<UserDto> me(String token) async =>
      UserDto.fromJson(await _request('GET', 'me', token: token), full: true);

  Future<void> revokeCurrentToken(String token) async {
    await _request('DELETE', 'auth/token', token: token);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    if (_closed) throw const ApiError('Запрос отменён.');
    final client = _client ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    HttpClientRequest? request;
    try {
      request = await client.openUrl(method, baseUri.resolve(path));
      if (_closed) {
        request.abort();
        throw const ApiError('Запрос отменён.');
      }
      // Redirects must never forward a bearer token to another endpoint.
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(responseTimeout);
      final status = response.statusCode;
      if (status == 401 && token != null) onUnauthorized?.call(token);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(responseTimeout);
      if (method == 'DELETE' && status == 204) return {};
      if (status == 401) {
        throw const ApiError('Сеанс истёк. Войдите снова.', statusCode: 401);
      }
      if (status == 429) {
        final retry = response.headers.value('retry-after');
        final seconds = int.tryParse(retry ?? '');
        final date = seconds == null && retry != null
            ? _retryDate(retry)
            : null;
        final wait = seconds ?? date?.difference(DateTime.now()).inSeconds;
        throw ApiError(
          wait != null && wait > 0
              ? 'Слишком много попыток. Повторите через $wait с.'
              : 'Слишком много попыток. Повторите позже.',
          statusCode: status,
        );
      }
      if (status >= 500) {
        throw ApiError('Ошибка сервера. Повторите позже.', statusCode: status);
      }
      if (status >= 300 && status < 400 || status == 404) {
        throw ApiError(
          'Неверный адрес API: маршрут недоступен.',
          statusCode: status,
        );
      }
      final mime = response.headers.contentType?.mimeType;
      if (mime != 'application/json' && !(mime?.endsWith('+json') ?? false)) {
        throw const ApiError(
          'API вернул не JSON. Проверьте адрес подключения.',
        );
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) throw _invalidResponse;
      if (status >= 400) {
        final errors = <String, String>{};
        final fields = decoded['errors'];
        if (fields is Map<String, dynamic>) {
          for (final field in fields.entries) {
            final messages = field.value;
            if (messages is List &&
                messages.isNotEmpty &&
                messages.first is String) {
              errors[field.key] = messages.first as String;
            }
          }
        }
        throw ApiError(
          decoded['message'] is String
              ? decoded['message'] as String
              : 'Запрос отклонён сервером.',
          statusCode: status,
          errors: errors,
        );
      }
      if (status != 200) throw _invalidResponse;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) throw _invalidResponse;
      return data;
    } on TimeoutException {
      request?.abort();
      throw const ApiError('Сервер не ответил вовремя. Повторите запрос.');
    } on FormatException {
      throw const ApiError('API вернул невалидный JSON. Проверьте сервер.');
    } on HandshakeException {
      throw const ApiError('Не удалось проверить сертификат HTTPS сервера.');
    } on IOException {
      throw const ApiError(
        'Нет соединения с сервером. Проверьте сеть и повторите.',
      );
    }
  }

  static DateTime? _retryDate(String value) {
    try {
      return HttpDate.parse(value);
    } on HttpException {
      return null;
    }
  }

  void close() {
    _closed = true;
    _client?.close(force: true);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const testUser = {
  'id': 7,
  'name': 'Учебный тренер',
  'email': 'trainer@example.test',
  'working_day_starts_at': '09:00:00',
  'working_day_ends_at': '18:00:00',
  'timezone': 'UTC',
};

const testToken = {
  'token': 'issued-only-by-test-server',
  'token_type': 'Bearer',
  'user': testUser,
};

Future<void> sendJson(
  HttpRequest request,
  Object body, {
  int status = 200,
}) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

class MobileApiServer {
  late final HttpServer _server;
  late Future<void> Function(HttpRequest request) handle;
  final requests = <String>[];
  final authorizations = <String?>[];
  Map<String, dynamic>? loginBody;

  String get baseUrl => 'http://127.0.0.1:${_server.port}/api/mobile/v1/';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    handle = respond;
    _server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      authorizations.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      await handle(request);
    });
  }

  Future<void> respond(HttpRequest request) async {
    if (request.method == 'DELETE') {
      request.response.statusCode = 204;
      await request.response.close();
    } else if (request.uri.path.endsWith('/health')) {
      await sendJson(request, {
        'data': {'status': 'ok', 'api_version': '1'},
      });
    } else if (request.uri.path.endsWith('/auth/token')) {
      loginBody = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      await sendJson(request, {'data': testToken});
    } else {
      await sendJson(request, {'data': testUser});
    }
  }

  Future<void> close() => _server.close(force: true);
}

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

class AuthRepository extends ChangeNotifier {
  AuthRepository({
    this.isDemo =
        const String.fromEnvironment('APP_MODE', defaultValue: 'demo') !=
        'server',
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
  });

  bool isDemo;
  String baseUrl;
  UserDto? user;
  ApiError? loginError;
  String? notice;
  bool signingIn = false;
  bool signingOut = false;
  bool showLogin = false;
  int navigationEpoch = 0;
  int _generation = 0;
  String? _token;
  ApiClient? _api;

  ApiClient _newClient() {
    final uri = ApiClient.parseBaseUrl(baseUrl);
    _api?.close();
    late final ApiClient client;
    client = ApiClient(
      uri,
      onUnauthorized: (token) {
        if (identical(_api, client) && _token == token) {
          _reset('Сеанс истёк. Войдите снова.');
        }
      },
    );
    return _api = client;
  }

  bool configure({required bool demo, required String url}) {
    final normalized = url.trim().isEmpty && demo
        ? ''
        : ApiClient.parseBaseUrl(url).toString();
    if (demo == isDemo && normalized == baseUrl) return false;
    isDemo = demo;
    baseUrl = normalized;
    _reset('Подключение изменено. Войдите снова.');
    return true;
  }

  Future<bool> signIn({required String email, required String password}) async {
    if (isDemo || signingIn || signingOut || user != null) return false;
    final generation = ++_generation;
    signingIn = true;
    loginError = null;
    notice = null;
    notifyListeners();
    try {
      final api = _newClient();
      final issued = await api.issueToken(email, password);
      if (generation != _generation) return false;
      final profile = await api.me(issued.token);
      if (generation != _generation) return false;
      _token = issued.token;
      user = profile;
      navigationEpoch++;
      return true;
    } on ApiError catch (error) {
      if (generation == _generation) loginError = error;
      return false;
    } finally {
      if (generation == _generation) {
        signingIn = false;
        notifyListeners();
      }
    }
  }

  void openDemo() {
    if (!isDemo || user != null) return;
    _generation++;
    _api?.close();
    _api = null;
    _token = null;
    user = const UserDto(
      id: 1,
      name: 'Демо-тренер',
      email: 'trainer@example.test',
      workingDayStartsAt: '09:00:00',
      workingDayEndsAt: '18:00:00',
      timezone: 'UTC',
    );
    notice = null;
    loginError = null;
    navigationEpoch++;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (signingOut) return;
    final generation = _generation;
    final token = _token;
    signingOut = true;
    notifyListeners();
    String? warning;
    try {
      if (token != null) await _api!.revokeCurrentToken(token);
    } on ApiError catch (error) {
      if (error.statusCode != 401) {
        warning =
            'Вы вышли на этом устройстве. Серверный токен не удалось отозвать.';
      }
    } finally {
      if (generation == _generation) _reset(warning);
    }
  }

  void clearLoginError() {
    if (loginError == null) return;
    loginError = null;
    notifyListeners();
  }

  void _reset(String? message) {
    _generation++;
    _api?.close();
    _api = null;
    _token = null;
    user = null;
    loginError = null;
    signingIn = false;
    signingOut = false;
    notice = message;
    showLogin = true;
    navigationEpoch++;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _api?.close();
    super.dispose();
  }
}

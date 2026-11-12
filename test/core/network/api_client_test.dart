import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tr_workspace/core/network/api_client.dart';

import '../../support/mobile_api_server.dart';

void main() {
  late MobileApiServer server;
  late ApiClient api;
  setUp(() async {
    server = MobileApiServer();
    await server.start();
    api = ApiClient(ApiClient.parseBaseUrl(server.baseUrl));
  });
  tearDown(() async {
    api.close();
    await server.close();
  });

  test('health, token, me and revoke match the wire contract', () async {
    expect((await api.health()).apiVersion, '1');
    final token = await api.issueToken(' trainer@example.test ', ' pass word ');
    final user = await api.me(token.token);
    expect(user.id, 7);
    expect(user.timezone, 'UTC');
    expect(user.workingDayStartsAt, '09:00:00');
    await api.revokeCurrentToken(token.token);
    expect(server.requests, [
      'GET /api/mobile/v1/health',
      'POST /api/mobile/v1/auth/token',
      'GET /api/mobile/v1/me',
      'DELETE /api/mobile/v1/auth/token',
    ]);
    expect(server.authorizations, [
      null,
      null,
      'Bearer ${token.token}',
      'Bearer ${token.token}',
    ]);
    expect(server.loginBody!['email'], 'trainer@example.test');
    expect(server.loginBody!['password'], ' pass word ');
    expect(
      (server.loginBody!['device_name'] as String).length,
      lessThanOrEqualTo(100),
    );
  });

  for (final value in [
    '',
    'https://example.test/',
    'https://example.test/api/mobile/v1',
    'https://user:secret@example.test/api/mobile/v1/',
    'https://example.test/api/mobile/v1/?token=secret',
    'https://example.test/api/mobile/v1/#fragment',
    'http://example.test/api/mobile/v1/',
    'file:///api/mobile/v1/',
  ]) {
    test('rejects unsafe or incorrect base URL: $value', () {
      expect(() => ApiClient.parseBaseUrl(value), throwsA(isA<ApiError>()));
    });
  }

  test('HTML 200 and malformed JSON are not healthy APIs', () async {
    server.handle = (r) async {
      r.response.headers.contentType = ContentType.html;
      r.response.write('<html>Welcome</html>');
      await r.response.close();
    };
    await expectLater(
      api.health(),
      throwsA(
        isA<ApiError>().having(
          (e) => e.message,
          'message',
          contains('не JSON'),
        ),
      ),
    );
    server.handle = (r) async {
      r.response.headers.contentType = ContentType.json;
      r.response.write('{broken');
      await r.response.close();
    };
    await expectLater(
      api.health(),
      throwsA(
        isA<ApiError>().having(
          (e) => e.message,
          'message',
          contains('невалидный JSON'),
        ),
      ),
    );
  });

  test('rejects incompatible version and incomplete DTOs', () async {
    server.handle = (r) => sendJson(r, {
      'data': {'status': 'ok', 'api_version': '2'},
    });
    await expectLater(api.health(), throwsA(isA<ApiError>()));
    expect(
      () => TokenData.fromJson({'token': 'x', 'token_type': 'Bearer'}),
      throwsA(isA<ApiError>()),
    );
    expect(
      () => UserDto.fromJson({'id': 0, 'name': 'X', 'email': 'x@y.test'}),
      throwsA(isA<ApiError>()),
    );
    server.handle = (r) => sendJson(r, {
      'data': {'id': 7, 'name': 'X', 'email': 'x@y.test'},
    });
    await expectLater(api.me('test'), throwsA(isA<ApiError>()));
  });

  test('422 works without optional code and retains field errors', () async {
    server.handle = (r) => sendJson(r, {
      'message': 'Проверьте форму.',
      'errors': {
        'email': ['Неверные данные.'],
      },
    }, status: 422);
    await expectLater(
      api.issueToken('x@y.test', 'x'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.errors['email'], 'email', 'Неверные данные.'),
      ),
    );
  });

  test('429 observes Retry-After and 5xx HTML gives a server error', () async {
    server.handle = (r) async {
      r.response.headers.set('retry-after', '60');
      await sendJson(r, {}, status: 429);
    };
    await expectLater(
      api.health(),
      throwsA(
        isA<ApiError>().having((e) => e.message, 'message', contains('60 с.')),
      ),
    );
    server.handle = (r) async {
      r.response.statusCode = 503;
      r.response.write('<html>Unavailable</html>');
      await r.response.close();
    };
    await expectLater(
      api.health(),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 503)),
    );
  });

  test('401 notifies only for the rejected protected request', () async {
    final rejected = <String>[];
    api.close();
    api = ApiClient(
      ApiClient.parseBaseUrl(server.baseUrl),
      onUnauthorized: rejected.add,
    );
    server.handle = (r) => sendJson(r, {}, status: 401);
    await expectLater(api.me('expired'), throwsA(isA<ApiError>()));
    await expectLater(
      api.issueToken('x@y.test', 'x'),
      throwsA(isA<ApiError>()),
    );
    expect(rejected, ['expired']);
  });

  test('redirect never receives a bearer token', () async {
    server.handle = (r) async {
      r.response.statusCode = 302;
      r.response.headers.set(HttpHeaders.locationHeader, '/external');
      await r.response.close();
    };
    await expectLater(api.me('private'), throwsA(isA<ApiError>()));
    expect(server.requests, ['GET /api/mobile/v1/me']);
  });

  test('timeout and disconnection are recoverable errors', () async {
    api.close();
    api = ApiClient(
      ApiClient.parseBaseUrl(server.baseUrl),
      responseTimeout: const Duration(milliseconds: 50),
    );
    final release = Completer<void>();
    server.handle = (r) async {
      await release.future;
      await r.response.close();
    };
    await expectLater(
      api.health(),
      throwsA(
        isA<ApiError>().having(
          (e) => e.message,
          'message',
          contains('вовремя'),
        ),
      ),
    );
    release.complete();
    server.handle = server.respond;
    expect((await api.health()).apiVersion, '1');
    await server.close();
    await expectLater(
      api.health(),
      throwsA(
        isA<ApiError>().having(
          (e) => e.message,
          'message',
          contains('Нет соединения'),
        ),
      ),
    );
  });
}

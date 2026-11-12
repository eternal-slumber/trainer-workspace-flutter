import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tr_workspace/features/auth/data/auth_repository.dart';

import '../../../support/mobile_api_server.dart';

void main() {
  late MobileApiServer server;
  late AuthRepository auth;
  setUp(() async {
    server = MobileApiServer();
    await server.start();
    auth = AuthRepository(isDemo: false, baseUrl: server.baseUrl);
  });
  tearDown(() async {
    auth.dispose();
    await server.close();
  });

  test('only me confirms a session; concurrent login is blocked', () async {
    final meStarted = Completer<void>();
    final release = Completer<void>();
    server.handle = (r) async {
      if (r.uri.path.endsWith('/me')) {
        meStarted.complete();
        await release.future;
      }
      await server.respond(r);
    };
    final login = auth.signIn(email: 'trainer@example.test', password: 'x');
    await meStarted.future;
    expect(auth.user, isNull);
    expect(auth.signingIn, isTrue);
    expect(
      await auth.signIn(email: 'trainer@example.test', password: 'x'),
      isFalse,
    );
    release.complete();
    expect(await login, isTrue);
    expect(auth.user!.name, 'Учебный тренер');
    expect(server.requests.length, 2);
    final restarted = AuthRepository(isDemo: false, baseUrl: server.baseUrl);
    expect(restarted.user, isNull);
    restarted.dispose();
    await auth.signOut();
    expect(auth.user, isNull);
    expect(auth.showLogin, isTrue);
    expect(server.requests.last, 'DELETE /api/mobile/v1/auth/token');
  });

  for (final status in [401, 422, 500]) {
    test(
      'failed me ($status) leaves no active session or demo fallback',
      () async {
        server.handle = (r) => r.uri.path.endsWith('/me')
            ? sendJson(r, {'message': 'Не удалось войти.'}, status: status)
            : server.respond(r);
        expect(await auth.signIn(email: 'x@y.test', password: 'x'), isFalse);
        expect(auth.user, isNull);
        expect(auth.signingIn, isFalse);
        expect(auth.isDemo, isFalse);
        expect(auth.loginError, isNotNull);
        auth.openDemo();
        expect(auth.user, isNull);
      },
    );
  }

  test('changing configuration cancels old login without touching the new demo session', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    server.handle = (r) async {
      started.complete();
      await release.future;
      await sendJson(r, {'message': 'Old session'}, status: 401);
    };
    final login = auth.signIn(email: 'x@y.test', password: 'x');
    await started.future;
    auth.configure(demo: true, url: server.baseUrl);
    auth.openDemo();
    release.complete();
    expect(await login, isFalse);
    expect(auth.user!.name, 'Демо-тренер');
    expect(auth.loginError, isNull);
    expect(auth.signingIn, isFalse);
  });

  test(
    'logout failure clears local session and reports unsuccessful revocation',
    () async {
      await auth.signIn(email: 'x@y.test', password: 'x');
      server.handle = (r) => sendJson(r, {}, status: 503);
      await auth.signOut();
      expect(auth.user, isNull);
      expect(auth.notice, contains('не удалось отозвать'));
      expect(auth.signingOut, isFalse);
    },
  );

  test('401 on logout invalidates only the current session', () async {
    await auth.signIn(email: 'x@y.test', password: 'x');
    server.handle = (r) => sendJson(r, {}, status: HttpStatus.unauthorized);
    await auth.signOut();
    expect(auth.user, isNull);
    expect(auth.notice, contains('Сеанс истёк'));
  });

  test(
    'switching server resets profile; no-op configuration preserves it',
    () async {
      await auth.signIn(email: 'x@y.test', password: 'x');
      expect(auth.configure(demo: false, url: server.baseUrl), isFalse);
      expect(auth.user, isNotNull);
      auth.configure(
        demo: false,
        url: 'https://other.example.test/api/mobile/v1/',
      );
      expect(auth.user, isNull);
      expect(auth.showLogin, isTrue);
    },
  );
}

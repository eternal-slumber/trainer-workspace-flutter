import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tr_workspace/app/app.dart';
import 'package:tr_workspace/features/auth/presentation/login_screen.dart';
import 'package:tr_workspace/features/auth/presentation/register_screen.dart';
import 'package:tr_workspace/features/auth/presentation/welcome_screen.dart';

void main() {
  final login = find.widgetWithText(FilledButton, 'Войти');
  final register = find.widgetWithText(OutlinedButton, 'Создать аккаунт');

  testWidgets('starts with welcome and bundled branding', (tester) async {
    await tester.pumpWidget(const TrainerWorkspaceApp());
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Trainer Workspace'), findsOneWidget);
    expect(
      find.text(
        'Управляйте клиентами, тренировками и расписанием в одном пространстве',
      ),
      findsOneWidget,
    );
    final logo = tester.widget<Image>(find.byType(Image));
    expect((logo.image as AssetImage).assetName, 'assets/icon/app_icon.png');
    expect(logo.semanticLabel, 'Логотип TW');
    expect(login, findsOneWidget);
    expect(register, findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final destination in [LoginScreen, RegisterScreen]) {
    testWidgets('opens $destination once and returns to welcome', (
      tester,
    ) async {
      await tester.pumpWidget(const TrainerWorkspaceApp());
      final firstAction = destination == LoginScreen ? login : register;
      final otherAction = destination == LoginScreen ? register : login;
      final repeatedTap = tester
          .widget<ButtonStyleButton>(firstAction)
          .onPressed!;
      final queuedOtherTap = tester
          .widget<ButtonStyleButton>(otherAction)
          .onPressed!;

      await tester.tap(firstAction);
      repeatedTap();
      queuedOtherTap();
      await tester.pumpAndSettle();

      expect(find.byType(destination, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(destination == LoginScreen ? RegisterScreen : LoginScreen),
        findsNothing,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('system back returns from authentication', (tester) async {
    await tester.pumpWidget(const TrainerWorkspaceApp());
    await tester.tap(login);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('welcome works with all HTTP access unavailable', (tester) async {
    var networkAttempts = 0;
    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(const TrainerWorkspaceApp());
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 10));
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(login.hitTestable(), findsOneWidget);
        expect(register.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      createHttpClient: (_) {
        networkAttempts++;
        throw const SocketException('No internet');
      },
    );
    expect(networkAttempts, 0);
  });

  for (final (size, scale) in [
    (const Size(320, 480), 1.0),
    (const Size(320, 480), 2.0),
    (const Size(320, 568), 3.0),
    (const Size(568, 320), 2.0),
  ]) {
    testWidgets('fits $size with text scale $scale and system insets', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const TrainerWorkspaceApp());
      await tester.pumpAndSettle();
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      expect(login.hitTestable(), findsOneWidget);
      await tester.ensureVisible(register);
      await tester.pumpAndSettle();
      expect(register.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(register).bottom,
        lessThanOrEqualTo(size.height - 34),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('welcome has accessible text and touch targets', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const TrainerWorkspaceApp());
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}

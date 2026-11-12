import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tr_workspace/app/app.dart';
import 'package:tr_workspace/core/network/api_client.dart';
import 'package:tr_workspace/features/auth/data/auth_repository.dart';
import 'package:tr_workspace/features/auth/presentation/login_screen.dart';
import 'package:tr_workspace/features/home/presentation/home_screen.dart';

class _PendingLogin extends AuthRepository {
  _PendingLogin()
    : super(isDemo: false, baseUrl: 'https://example.test/api/mobile/v1/');
  final result = Completer<void>();
  int calls = 0;

  @override
  Future<bool> signIn({required String email, required String password}) async {
    calls++;
    signingIn = true;
    notifyListeners();
    await result.future;
    signingIn = false;
    loginError = const ApiError(
      'Проверьте данные.',
      statusCode: 422,
      errors: {'email': 'Неверные учётные данные.'},
    );
    notifyListeners();
    return false;
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('demo, about, logout and Back never restore a closed session', (
    tester,
  ) async {
    await tester.pumpWidget(const TrainerWorkspaceApp());
    expect(find.text('Демонстрационные данные'), findsOneWidget);
    expect(find.text('Режим: Демо'), findsOneWidget);
    await tapText(tester, 'Войти');
    expect(find.byType(TextFormField), findsNothing);
    await tapText(tester, 'Открыть демо');
    expect(find.text('Здравствуйте, Демо-тренер!'), findsOneWidget);
    await tapText(tester, 'О приложении');
    expect(find.text('Hello, Android!'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Выйти');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection validates URL and changing mode resets the session', (
    tester,
  ) async {
    await tester.pumpWidget(const TrainerWorkspaceApp());
    await tapText(tester, 'Подключение');
    await tester.enterText(find.byType(TextField), 'https://example.test/');
    await tapText(tester, 'Проверить подключение');
    expect(find.textContaining('Укажите адрес вида'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'https://example.test/api/mobile/v1/',
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tapText(tester, 'Сохранить подключение');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Режим: Сервер'), findsOneWidget);
    expect(find.text('Демонстрационные данные'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'login validates, blocks duplicates across rotation and clears password on 422',
    (tester) async {
      final auth = _PendingLogin();
      addTearDown(auth.dispose);
      await tester.pumpWidget(TrainerWorkspaceApp(authRepository: auth));
      await tapText(tester, 'Войти');
      await tapText(tester, 'Войти');
      expect(auth.calls, 0);
      expect(find.text('Введите email'), findsOneWidget);
      expect(find.text('Введите пароль'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'bad-email');
      await tester.enterText(fields.last, ' x ');
      await tapText(tester, 'Войти');
      expect(auth.calls, 0);
      await tester.enterText(fields.first, 'trainer@example.test');
      final button = find.widgetWithText(FilledButton, 'Войти');
      await tester.ensureVisible(button);
      final queuedTap = tester.widget<FilledButton>(button).onPressed!;
      await tester.tap(button);
      queuedTap();
      await tester.pump();
      expect(auth.calls, 1);
      expect(find.text('Входим…'), findsOneWidget);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 320);
      addTearDown(tester.view.reset);
      await tester.pump();
      expect(auth.calls, 1);
      auth.result.complete();
      await tester.pumpAndSettle();
      expect(find.text('Неверные учётные данные.'), findsOneWidget);
      final inputs = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(inputs.first.controller.text, 'trainer@example.test');
      expect(inputs.last.controller.text, isEmpty);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new demo screens support small screens, large text and accessible targets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const TrainerWorkspaceApp());
        await tapText(tester, 'Войти');
        await tapText(tester, 'Открыть демо');
        await tester.ensureVisible(find.text('Выйти'));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tapText(tester, 'Подключение');
        await tester.ensureVisible(find.text('Сохранить подключение'));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

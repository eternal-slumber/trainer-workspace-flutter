import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tr_workspace/app/app.dart';
import 'package:tr_workspace/features/auth/presentation/login_screen.dart';
import 'package:tr_workspace/features/auth/presentation/register_screen.dart';

Future<void> _openRegistration(WidgetTester tester) async {
  await tester.pumpWidget(const TrainerWorkspaceApp());
  final register = find.widgetWithText(OutlinedButton, 'Создать аккаунт');
  await tester.ensureVisible(register);
  await tester.pumpAndSettle();
  await tester.tap(register);
  await tester.pumpAndSettle();
}

void main() {
  final fields = find.byType(TextFormField);
  final submit = find.widgetWithText(FilledButton, 'Создать аккаунт');

  testWidgets('registration validates input and keeps submission local', (
    tester,
  ) async {
    await _openRegistration(tester);
    expect(fields, findsNWidgets(4));
    expect(find.text('Введите имя'), findsNothing);

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Введите имя'), findsOneWidget);
    expect(find.text('Введите email'), findsOneWidget);
    expect(
      find.text('Пароль должен содержать не менее 8 символов'),
      findsOneWidget,
    );

    await tester.enterText(fields.at(0), 'Иван Петров');
    await tester.enterText(fields.at(1), 'invalid-email');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'different');
    await tester.pumpAndSettle();
    expect(find.text('Проверьте адрес электронной почты'), findsOneWidget);
    expect(find.text('Пароли не совпадают'), findsOneWidget);

    await tester.enterText(fields.at(1), 'ivan@example.com');
    await tester.enterText(fields.at(3), 'password123');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Демонстрация: аккаунт не создан.'), findsOneWidget);
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password toggles preserve input and work independently', (
    tester,
  ) async {
    await _openRegistration(tester);
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'password123');

    final passwordToggle = find.byTooltip('Показать пароль');
    await tester.ensureVisible(passwordToggle);
    await tester.tap(passwordToggle);
    await tester.pumpAndSettle();
    final inputs = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(inputs[2].obscureText, isFalse);
    expect(inputs[2].controller.text, 'password123');
    expect(inputs[3].obscureText, isTrue);

    final confirmationToggle = find.byTooltip('Показать подтверждение пароля');
    await tester.ensureVisible(confirmationToggle);
    await tester.tap(confirmationToggle);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .last
          .obscureText,
      isFalse,
    );
    expect(find.byTooltip('Скрыть пароль'), findsOneWidget);
  });

  testWidgets('login navigation preserves registration when returning', (
    tester,
  ) async {
    await _openRegistration(tester);
    await tester.enterText(fields.first, 'Иван Петров');
    final loginLink = find.widgetWithText(TextButton, 'Войти');
    await tester.ensureVisible(loginLink);
    await tester.tap(loginLink);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Иван Петров',
    );
  });

  testWidgets('small screen, large text and keyboard remain scrollable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openRegistration(tester);
    await tester.ensureVisible(fields.last);
    await tester.enterText(fields.last, 'password123');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Введите имя'), findsOneWidget);
    expect(tester.getRect(fields.first).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(fields.first).bottom, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout stays compact and controls have accessible labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      await _openRegistration(tester);
      expect(tester.getSize(fields.first).width, 400);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

import 'package:flutter/material.dart';

import '../../../app/auth_navigation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _submitted = false;

  void _submitForm() {
    setState(() => _submitted = true);
    final invalidFields = _formKey.currentState!.validateGranularly();
    if (invalidFields.isNotEmpty) {
      Scrollable.ensureVisible(
        invalidFields.first.context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    // shortcut: demo only; connect registration when the auth API is ready.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Демонстрация: аккаунт не создан.')),
      );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'Trainer Workspace',
                          children: [
                            TextSpan(
                              text: '.',
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        semanticsLabel: 'Trainer Workspace',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 40),
                      Semantics(
                        header: true,
                        child: Text(
                          'Создать аккаунт',
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Введите данные для регистрации.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const ExcludeSemantics(
                        child: Text('Имя', style: labelStyle),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Имя',
                        child: TextFormField(
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            hintText: 'Иван Петров',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Введите имя'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const ExcludeSemantics(
                        child: Text('Электронная почта', style: labelStyle),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Электронная почта',
                        child: TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            hintText: 'name@example.com',
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Введите email';
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)) {
                              return 'Проверьте адрес электронной почты';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const ExcludeSemantics(
                        child: Text('Пароль', style: labelStyle),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Пароль',
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'Придумайте пароль',
                            helperText: 'Не менее 8 символов',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Показать пароль'
                                  : 'Скрыть пароль',
                              iconSize: 20,
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 8
                              ? 'Пароль должен содержать не менее 8 символов'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const ExcludeSemantics(
                        child: Text('Подтверждение пароля', style: labelStyle),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Подтверждение пароля',
                        child: TextFormField(
                          obscureText: _obscureConfirmation,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'Повторите пароль',
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmation
                                  ? 'Показать подтверждение пароля'
                                  : 'Скрыть подтверждение пароля',
                              iconSize: 20,
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmation =
                                    !_obscureConfirmation,
                              ),
                            ),
                          ),
                          onFieldSubmitted: (_) => _submitForm(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Повторите пароль';
                            }
                            return value != _passwordController.text
                                ? 'Пароли не совпадают'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _submitForm,
                        child: const Text('Создать аккаунт'),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Уже есть аккаунт?',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () => AuthNavigation.openLogin(context),
                            child: Text(
                              'Войти',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/auth_navigation.dart';
import '../../../app/auth_scope.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _submit() async {
    final auth = AuthScope.of(context);
    if (auth.signingIn || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      await auth.signIn(email: _email.text, password: _password.text);
    } finally {
      if (mounted) _password.clear();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final error = auth.loginError;
    return PopScope(
      canPop: !auth.signingIn,
      child: Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Войдите в рабочее пространство',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text('Режим: ${auth.isDemo ? 'Демо' : 'Сервер'}'),
                      TextButton(
                        onPressed: () => AuthNavigation.openConnection(context),
                        child: const Text('Подключение'),
                      ),
                      if (auth.notice != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(auth.notice!),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (auth.isDemo) ...[
                        const Text(
                          'Откройте учебное рабочее пространство без пароля. Данные вымышленные.',
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: auth.openDemo,
                          child: const Text('Открыть демо'),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _email,
                          enabled: !auth.signingIn,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Электронная почта',
                            errorText: error?.errors['email'],
                          ),
                          onChanged: (_) => auth.clearLoginError(),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Введите email';
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)) {
                              return 'Некорректный email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _password,
                          enabled: !auth.signingIn,
                          obscureText: _obscurePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: (_) => auth.clearLoginError(),
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            errorText: error?.errors['password'],
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Показать пароль'
                                  : 'Скрыть пароль',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Введите пароль'
                              : null,
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                [
                                  error.message,
                                  if (error.errors['device_name'] != null)
                                    error.errors['device_name']!,
                                ].join('\n'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: auth.signingIn ? null : _submit,
                          child: Text(auth.signingIn ? 'Входим…' : 'Войти'),
                        ),
                        if (auth.signingIn)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
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

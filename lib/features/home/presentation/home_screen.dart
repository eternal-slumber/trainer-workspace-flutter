import 'package:flutter/material.dart';

import '../../../app/auth_navigation.dart';
import '../../../app/auth_scope.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('TrainerWorkspace')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Здравствуйте, ${auth.user!.name}!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text('Режим: ${auth.isDemo ? 'Демо' : 'Сервер'}'),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: auth.signingOut
                        ? null
                        : () => AuthNavigation.openConnection(context),
                    child: const Text('Подключение'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: auth.signingOut
                        ? null
                        : () => AuthNavigation.openAbout(context),
                    child: const Text('О приложении'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: auth.signingOut ? null : auth.signOut,
                    child: Text(auth.signingOut ? 'Выходим…' : 'Выйти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/home/presentation/home_screen.dart';
import 'auth_scope.dart';

class TrainerWorkspaceApp extends StatefulWidget {
  const TrainerWorkspaceApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<TrainerWorkspaceApp> createState() => _TrainerWorkspaceAppState();
}

class _TrainerWorkspaceAppState extends State<TrainerWorkspaceApp> {
  late final _auth = widget.authRepository ?? AuthRepository();

  @override
  void dispose() {
    if (widget.authRepository == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      repository: _auth,
      child: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) => MaterialApp(
          key: ValueKey(_auth.navigationEpoch),
          title: 'Trainer Workspace',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: _auth.user != null
              ? const HomeScreen()
              : _auth.showLogin
              ? const LoginScreen()
              : const WelcomeScreen(),
          builder: (context, child) => _auth.isDemo
              ? ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Material(
                          color: const Color(0xFFFFE6DE),
                          child: SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                'Демонстрационные данные',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: Color(0xFF1B1B18),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: child!),
                      ],
                    ),
                  ),
                )
              : child!,
        ),
      ),
    );
  }
}

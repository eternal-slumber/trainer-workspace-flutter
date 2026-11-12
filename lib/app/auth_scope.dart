import 'package:flutter/widgets.dart';

import '../features/auth/data/auth_repository.dart';

class AuthScope extends InheritedNotifier<AuthRepository> {
  const AuthScope({
    super.key,
    required AuthRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AuthRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}

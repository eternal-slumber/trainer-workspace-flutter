import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';

abstract final class AuthNavigation {
  static void openLogin(BuildContext context) {
    _open(context, const LoginScreen());
  }

  static void openRegister(BuildContext context) {
    _open(context, const RegisterScreen());
  }

  static void _open(BuildContext context, Widget screen) {
    if (ModalRoute.of(context)?.isCurrent != true) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

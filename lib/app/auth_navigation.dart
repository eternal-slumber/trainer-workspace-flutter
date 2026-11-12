import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/connection/presentation/connection_screen.dart';
import '../features/home/presentation/about_screen.dart';

abstract final class AuthNavigation {
  static void openConnection(BuildContext context) {
    _open(context, const ConnectionScreen());
  }

  static void openAbout(BuildContext context) {
    _open(context, const AboutScreen());
  }

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

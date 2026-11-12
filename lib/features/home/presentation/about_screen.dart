import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('О приложении')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TrainerWorkspace',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const Text('Hello, Android!'),
            const SizedBox(height: 16),
            const Text(
              'Мобильное рабочее пространство фитнес-тренера. Лабораторная работа 1.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Токен хранится только в памяти. После завершения процесса требуется повторный вход.',
            ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../app/auth_scope.dart';
import '../../../core/network/api_client.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _url = TextEditingController();
  bool? _demo;
  bool _checking = false;
  String? _error;
  HealthResponse? _health;
  ApiClient? _probe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_demo == null) {
      final auth = AuthScope.of(context);
      _demo = auth.isDemo;
      _url.text = auth.baseUrl;
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
      _health = null;
    });
    try {
      final probe = _probe = ApiClient(ApiClient.parseBaseUrl(_url.text));
      final health = await probe.health();
      if (mounted) setState(() => _health = health);
    } on ApiError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      _probe?.close();
      _probe = null;
      if (mounted) setState(() => _checking = false);
    }
  }

  void _save() {
    try {
      final changed = AuthScope.of(context)
          .configure(demo: _demo!, url: _url.text);
      if (!changed) Navigator.of(context).pop();
    } on ApiError catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  void dispose() {
    _probe?.close();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Подключение')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Демонстрационный режим'),
                    subtitle: Text(
                      _demo!
                          ? 'Данные только на этом устройстве'
                          : 'Работа с сервером',
                    ),
                    value: _demo!,
                    onChanged: _checking
                        ? null
                        : (value) => setState(() {
                            _demo = value;
                            _error = null;
                            _health = null;
                          }),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _url,
                    enabled: !_checking,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Адрес API',
                      hintText: 'https://сервер/api/mobile/v1/',
                    ),
                    onChanged: (_) => setState(() {
                      _error = null;
                      _health = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Без логина, пароля и токена в адресе. Проверка выполняется без входа.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _checking ? null : _check,
                    child: Text(
                      _checking
                          ? 'Проверяем подключение…'
                          : 'Проверить подключение',
                    ),
                  ),
                  if (_checking)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_health != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Подключение установлено. Версия API: ${_health!.apiVersion}',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (auth.user != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Смена режима или сервера завершит текущий сеанс.',
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _checking ? null : _save,
                    child: const Text('Сохранить подключение'),
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

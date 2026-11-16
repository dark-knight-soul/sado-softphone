import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/strings.dart';
import '../platform/call_keeper.dart';
import '../sip/call_engine.dart';
import '../state/session.dart';
import '../state/setup_link.dart';
import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _number = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  LinkError? _error;

  /// Поля заполнены ссылкой настройки — над кнопкой просим проверить адрес сервера.
  bool _fromLink = false;

  @override
  void initState() {
    super.initState();
    // Ссылка настройки (QR-код) заполняет форму, но не входит: «Войти» человек нажимает сам.
    // fireImmediately: ссылка могла прийти раньше, чем экран построился.
    ref.listenManual(setupRequestProvider, (_, next) {
      if (next == null) return;
      _applyLink(next);
      // Забываем запрос (и пароль в нём) после кадра: стирать состояние посреди рассылки нельзя.
      Future.microtask(() {
        if (mounted) ref.read(setupRequestProvider.notifier).clear();
      });
    }, fireImmediately: true);
  }

  /// Переносит данные ссылки в поля. Пароль после этого хранится только в поле пароля.
  void _applyLink(SetupLink link) {
    if (_busy) return; // идёт вход — не подменяем данные у него под ногами
    _server.text = link.server;
    _number.text = link.number;
    _password.text = link.password ?? '';
    setState(() {
      _fromLink = true;
      _error = null;
    });
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// «Войти по QR-коду»: открываем сканер и переносим прочитанную ссылку настройки в поля.
  /// Как и ссылка, код только заполняет форму — «Войти» человек нажимает сам.
  Future<void> _scan() async {
    final s = S.of(context);
    final scan = await ref.read(callKeeperProvider).scanQr(hint: s.scanHint, close: s.cancel);
    if (!mounted) return;
    switch (scan.status) {
      case QrScanStatus.ok:
        final link = parseSetupLink(scan.text ?? '');
        if (link == null) {
          _say(s.scanNotSetup);
        } else {
          _applyLink(link);
        }
      case QrScanStatus.cancelled:
        break;
      case QrScanStatus.denied:
        _say(s.scanNoCamera);
      case QrScanStatus.unavailable:
        // Сканера здесь нет (например, в браузере) — подсказываем прежний путь: обычная камера телефона.
        _say(s.qrHint);
    }
  }

  /// Запасной путь: камера только скопировала текст QR-кода — берём ссылку из буфера обмена.
  Future<void> _paste() async {
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      text = null; // буфер недоступен — то же, что в нём нет ссылки
    }
    if (!mounted) return;
    final link = text == null ? null : parseSetupLink(text);
    if (link == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.of(context).noSetupInClipboard)));
      return;
    }
    _applyLink(link);
  }

  @override
  void dispose() {
    _server.dispose();
    _number.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    await _signIn(server: _server.text.trim(), number: _number.text.trim(), password: _password.text);
  }

  /// Вход проверяет номер и пароль на АТС; при отказе показываем причину прямо под полями.
  Future<void> _signIn({required String server, required String number, required String password}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    LinkStatus result;
    try {
      result = await ref.read(sessionProvider.notifier).signIn(server: server, number: number, password: password);
    } catch (_) {
      result = const LinkStatus(LinkState.failed, LinkError.other);
    }
    if (!mounted || result.isOnline) return;
    setState(() {
      _busy = false;
      _error = result.error ?? LinkError.other;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final style = SadoStyle.of(context);
    final p = style.palette;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? s.fieldRequired : null;
    final errorText = switch (_error) {
      null => null,
      LinkError.auth => s.errAuth,
      LinkError.network => s.errNetwork,
      LinkError.other => s.errOther,
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(24)),
                      child: Icon(Icons.graphic_eq, color: p.onAccent, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SADO',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.text),
                    ),
                    const SizedBox(height: 4),
                    Text(s.tagline, style: TextStyle(fontSize: 15, color: p.muted)),
                    const SizedBox(height: 36),
                    TextFormField(
                      key: const Key('login.server'),
                      controller: _server,
                      enabled: !_busy,
                      validator: required,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      // Перерисовываем экран при вводе: под полем появляется предупреждение о незашифрованном адресе.
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: s.server, hintText: 'pbx.example.com'),
                    ),
                    if (_server.text.trim().toLowerCase().startsWith('ws://'))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: Text(
                          s.insecureServer,
                          key: const Key('login.insecure'),
                          style: TextStyle(fontSize: 13, height: 1.35, color: p.danger),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('login.number'),
                      controller: _number,
                      enabled: !_busy,
                      validator: required,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: s.number, hintText: '1003'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('login.password'),
                      controller: _password,
                      enabled: !_busy,
                      validator: required,
                      obscureText: _hidePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: s.password,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidePassword ? SadoIcons.of(context).show : SadoIcons.of(context).hide,
                            color: p.muted,
                          ),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        errorText,
                        key: const Key('login.error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: p.danger),
                      ),
                    ],
                    if (_fromLink) ...[
                      const SizedBox(height: 14),
                      Text(
                        s.setupFilled,
                        key: const Key('login.fromLink'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, height: 1.35, color: p.muted),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('login.submit'),
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? s.signingIn : s.signIn),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const Key('login.qr'),
                      onPressed: _busy ? null : _scan,
                      icon: Icon(SadoIcons.of(context).qr),
                      label: Text(s.signInQr),
                    ),
                    TextButton.icon(
                      key: const Key('login.paste'),
                      onPressed: _busy ? null : _paste,
                      icon: const Icon(Icons.content_paste_rounded),
                      label: Text(s.pasteSetup),
                    ),
                    TextButton(
                      key: const Key('login.demo'),
                      onPressed: _busy ? null : () => _signIn(server: Account.demoServer, number: '1003', password: ''),
                      child: Text(s.tryDemo),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/strings.dart';
import '../sip/call_engine.dart';
import '../state/session.dart';
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
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('login.submit'),
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? s.signingIn : s.signIn),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.soon))),
                      icon: Icon(SadoIcons.of(context).qr),
                      label: Text(s.signInQr),
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

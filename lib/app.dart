import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/strings.dart';
import 'state/call.dart';
import 'state/presence.dart';
import 'state/session.dart';
import 'state/settings.dart';
import 'theme/sado_icons.dart';
import 'theme/sado_style.dart';
import 'theme/styles.dart';
import 'ui/call_screens.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';
import 'ui/widgets.dart';

class SadoApp extends ConsumerWidget {
  const SadoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Уведомления о звонке и режим «на связи» (см. presence.dart).
    ref.watch(presenceProvider);
    final settings = ref.watch(settingsProvider);
    final spec = styleSpecOf(settings.styleId);
    final icons = SadoIcons.byId(settings.iconSet);
    return MaterialApp(
      title: 'SADO',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(spec, Brightness.light, icons),
      darkTheme: buildTheme(spec, Brightness.dark, icons),
      themeMode: settings.themeMode,
      locale: settings.lang == null ? null : Locale(settings.lang!),
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [S.delegate, ...GlobalMaterialLocalizations.delegates],
      home: const RootView(),
    );
  }
}

/// Решает, что показывать: вход или основное приложение, и поверх — экран звонка, если звонок идёт.
class RootView extends ConsumerWidget {
  const RootView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider.select((a) => a != null));
    final phase = ref.watch(callProvider.select((c) => c?.phase));
    // Звонок появился или закончился — убираем всё, что открыто поверх: нижние окна (иначе экран звонка
    // оказался бы под ними, а окно перевода пережило бы сам разговор) и клавиатуру телефона.
    ref.listen(callProvider.select((c) => c != null), (prev, next) {
      if (prev == next) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      FocusManager.instance.primaryFocus?.unfocus();
    });
    ref.listen(callFailureProvider, (prev, next) {
      final failure = next.value;
      // При смене учётной записи источник сообщений перезапускается и ещё «помнит» прошлое — его не повторяем.
      if (next.isLoading || failure == null || identical(prev?.value, failure)) return;
      final s = S.of(context);
      final text = switch (failure.kind) {
        CallFailure.busy => s.failBusy,
        CallFailure.rejected => s.failRejected,
        CallFailure.noAnswer => s.failNoAnswer,
        CallFailure.unavailable => s.failUnavailable,
        CallFailure.micDenied => s.failMic,
        CallFailure.offline => s.failOffline,
        CallFailure.other => s.failOther,
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(SadoStyle.of(context).palette.bg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          signedIn ? const HomeShell() : const LoginScreen(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (phase) {
              null => const SizedBox.shrink(key: ValueKey('call.none')),
              CallPhase.incoming => const IncomingCallScreen(key: ValueKey('call.incoming')),
              _ => const CallScreen(key: ValueKey('call.active')),
            },
          ),
        ],
      ),
    );
  }
}

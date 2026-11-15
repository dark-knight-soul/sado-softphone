import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../platform/call_keeper.dart';
import '../sip/call_engine.dart';
import 'call.dart';
import 'dial_request.dart';
import 'session.dart';
import 'settings.dart';

/// Следит за звонком, связью и настройками и говорит телефону, что показывать в шторке
/// и как себя вести ([CallKeeper]):
///
///  - звонка нет, человек вошёл и разрешил работу в фоне → режим ожидания «на связи»;
///  - входящий → звонок на весь экран с мелодией;
///  - вызов или разговор → уведомление с «Завершить», экран гаснет у уха.
///
/// Работает и без окна приложения: его запускает `main()`, а не экраны.
class _Presence {
  _Presence(this._ref, this._keeper);

  final Ref _ref;
  final CallKeeper _keeper;

  // Что уже передано телефону — чтобы не дёргать его без изменений.
  String? _shown;
  bool _proximity = false;
  bool _overLock = false;

  void sync() {
    final call = _ref.read(callProvider);
    final account = _ref.read(sessionProvider);
    final settings = _ref.read(settingsProvider);
    final s = S.byCode(settings.lang ?? PlatformDispatcher.instance.locale.languageCode);

    final String next;
    if (call != null) {
      final title = s.caller(call.name, call.number);
      if (call.phase == CallPhase.incoming) {
        final silent = _ref.read(ringSilencedProvider);
        next = 'ring|$title|$silent';
        if (next != _shown) {
          _keeper.ring(
            title: title,
            text: s.incomingCall,
            acceptLabel: s.accept,
            declineLabel: s.decline,
            silent: silent,
          );
        }
      } else {
        final text = call.phase == CallPhase.outgoing ? s.calling : (call.held ? s.onHold : s.inCall);
        next = 'show|$title|$text';
        if (next != _shown) _keeper.show(title: title, text: text, hangUpLabel: s.hangUp);
      }
    } else if (account != null && !account.isDemo && settings.backgroundLink) {
      final link = _ref.read(linkProvider);
      final text = switch (link.state) {
        LinkState.online when settings.dnd => s.dndStatus(account.number),
        LinkState.online => s.online(account.number),
        LinkState.connecting => s.linkConnecting(account.number),
        LinkState.failed when link.error == LinkError.auth => s.linkAuth(account.number),
        LinkState.failed || LinkState.offline => s.linkOffline(account.number),
      };
      next = 'standby|$text';
      if (next != _shown) _keeper.standby(title: 'SADO', text: text);
    } else {
      next = 'none';
      // Прячем и при самом первом проходе: службу могла поднять перезагрузка телефона, хотя человек
      // вышел из учётной записи или выключил «Звонки в фоне».
      if (_shown != next) _keeper.hide();
    }
    _shown = next;

    // Экран гасим у уха только в разговоре через трубку (не динамик и не гарнитура): при входящем на него нужно смотреть.
    final proximity = call != null && call.phase != CallPhase.incoming && call.route == AudioKind.earpiece;
    if (proximity != _proximity) {
      _proximity = proximity;
      _keeper.setProximity(proximity);
    }
    // Поверх экрана блокировки окно показываем только пока есть звонок.
    final overLock = call != null;
    if (overLock != _overLock) {
      _overLock = overLock;
      _keeper.setOverLockScreen(overLock);
    }
  }
}

/// Достаточно один раз прочитать этот провайдер — дальше он работает сам.
final presenceProvider = Provider<void>((ref) {
  final keeper = ref.watch(callKeeperProvider);
  final presence = _Presence(ref, keeper);
  keeper.onHangUp = () => ref.read(callProvider.notifier).hangUp();
  keeper.onAccept = () => ref.read(callProvider.notifier).accept();
  keeper.onMissedSeen = () => ref.read(callProvider.notifier).resetMissed();
  keeper.onDialRequest = (number) => ref.read(dialRequestProvider.notifier).request(number);
  // Ссылка могла открыть приложение при холодном запуске, пока событие некуда было доставить.
  keeper.takePendingDial().then((number) {
    if (number != null && ref.mounted) ref.read(dialRequestProvider.notifier).request(number);
  });

  ref.listen(callProvider, (_, _) => presence.sync());
  ref.listen(linkProvider, (_, _) => presence.sync());
  ref.listen(sessionProvider, (_, _) => presence.sync());
  ref.listen(settingsProvider, (_, _) => presence.sync());
  ref.listen(ringSilencedProvider, (_, _) => presence.sync());
  presence.sync();
});

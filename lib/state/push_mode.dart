import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/call_keeper.dart';
import 'call.dart';
import 'session.dart';
import 'settings.dart';

/// Как АТС может разбудить этот телефон push-уведомлением; null — push здесь нет (сборка без сервисов
/// Google, телефон без них, не Android). Спрашивается у телефона при запуске и когда адрес сменился.
class PushInfoController extends Notifier<PushInfo?> {
  @override
  PushInfo? build() {
    final keeper = ref.watch(callKeeperProvider);
    keeper.onPushTokenChanged = () => unawaited(refresh());
    unawaited(refresh());
    return null;
  }

  Future<void> refresh() async {
    PushInfo? info;
    try {
      info = await ref.read(callKeeperProvider).pushInfo().timeout(const Duration(seconds: 6));
    } catch (_) {
      info = null; // телефон не ответил — считаем, что push нет
    }
    if (ref.mounted && info != state) state = info;
  }
}

final pushInfoProvider = NotifierProvider<PushInfoController, PushInfo?>(PushInfoController.new);

/// Режим «будить по звонку» действует: он выбран в настройках, звонки в фоне разрешены, человек вошёл
/// в настоящую учётную запись и push на телефоне есть. Значение — сведения для АТС; null — режим не действует.
final pushModeProvider = Provider<PushInfo?>((ref) {
  final chosen = ref.watch(settingsProvider.select((s) => s.backgroundLink && s.pushWake));
  final account = ref.watch(sessionProvider);
  if (!chosen || account == null || account.isDemo) return null;
  return ref.watch(pushInfoProvider);
});

/// «Спит» ли приложение в режиме «будить по звонку» (true — ушло со связи и ждёт push).
///
/// Приложение бодрствует, пока его видно на экране, пока идёт звонок и ещё немного после: после запуска
/// (успеть сообщить АТС адрес для push), после сворачивания и после звонка. Получив push, оно бодрствует
/// дольше — ждёт сам звонок. В остальное время уходит со связи; фоновую службу тогда убирает presence.dart.
class PushSleepController extends Notifier<bool> with WidgetsBindingObserver {
  /// Сколько ждать звонка после push «проснись».
  static const wakeWindow = Duration(seconds: 40);

  /// Сколько оставаться на связи после запуска, сворачивания и конца звонка.
  static const linger = Duration(seconds: 20);

  /// Пауза между снятием регистрации и остановкой фоновой службы: запрос к АТС должен успеть уйти.
  static const _farewell = Duration(milliseconds: 1500);

  bool _visible = false;
  DateTime _awakeUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  bool _goingToSleep = false;

  /// Движку уже сказано уйти со связи (даже если фоновая служба ещё не убрана).
  bool _engineAsleep = false;

  @override
  bool build() {
    final keeper = ref.watch(callKeeperProvider);
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() {
      binding.removeObserver(this);
      _timer?.cancel();
    });
    _visible = _isVisible(binding.lifecycleState);
    _stayAwake(linger);

    keeper.onPushWake = () {
      _stayAwake(wakeWindow);
      _evaluate();
    };
    // Push мог запустить приложение раньше, чем этот код начал слушать события.
    keeper.takePushWake().then((woken) {
      if (!woken || !ref.mounted) return;
      _stayAwake(wakeWindow);
      _evaluate();
    });

    ref.listen(pushModeProvider, (previous, next) {
      // Режим включили, выключили или сменился адрес телефона — АТС должна узнать об этом сразу.
      _stayAwake(linger);
      unawaited(ref.read(sessionProvider.notifier).usePush(next));
      _evaluate();
    });
    // Звонок закончился — ещё немного остаёмся на связи: могут перезвонить.
    void callChanged({required bool ended}) {
      if (ended) _stayAwake(linger);
      _evaluate();
    }

    ref.listen(callProvider, (previous, next) => callChanged(ended: previous != null && next == null));
    ref.listen(otherCallProvider, (previous, next) => callChanged(ended: previous != null && next == null));
    Future.microtask(() {
      if (ref.mounted) _evaluate();
    });
    return false;
  }

  static bool _isVisible(AppLifecycleState? state) =>
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  void _stayAwake(Duration time) {
    final until = clock.now().add(time);
    if (until.isAfter(_awakeUntil)) _awakeUntil = until;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = _isVisible(state);
    if (_visible && !visible) _stayAwake(linger);
    _visible = visible;
    _evaluate();
  }

  void _evaluate() {
    _timer?.cancel();
    if (ref.read(pushModeProvider) == null) {
      // Режим не действует: приложение на связи постоянно (или не на связи вовсе — это решают другие).
      _goingToSleep = false;
      _engineAsleep = false;
      if (state) state = false;
      return;
    }
    final now = clock.now();
    final inCall = ref.read(callProvider) != null || ref.read(otherCallProvider) != null;
    if (_visible || inCall || now.isBefore(_awakeUntil)) {
      _goingToSleep = false;
      if (state) state = false;
      if (_engineAsleep) {
        _engineAsleep = false;
        unawaited(ref.read(sessionProvider.notifier).wake());
      }
      if (!_visible && !inCall) {
        _timer = Timer(_awakeUntil.difference(now) + const Duration(milliseconds: 50), _evaluate);
      }
      return;
    }
    if (state || _goingToSleep) return;
    _goingToSleep = true;
    unawaited(_sleep());
  }

  Future<void> _sleep() async {
    _engineAsleep = true;
    await ref.read(sessionProvider.notifier).sleep();
    await Future<void>.delayed(_farewell);
    // За это время приложение могли открыть или разбудить — тогда спать уже не нужно.
    if (!ref.mounted || !_goingToSleep) return;
    _goingToSleep = false;
    state = true;
  }
}

final pushAsleepProvider = NotifierProvider<PushSleepController, bool>(PushSleepController.new);

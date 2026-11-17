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
  /// Через сколько спрашивать снова, если режим выбран, а телефон сведений не дал (например, сервисы Google
  /// ещё не проснулись после включения телефона). После последней попытки ждём до следующего запуска.
  static const retryAfter = [Duration(seconds: 15), Duration(minutes: 1), Duration(minutes: 5)];

  Timer? _retry;
  int _attempt = 0;

  @override
  PushInfo? build() {
    final keeper = ref.watch(callKeeperProvider);
    keeper.onPushTokenChanged = () => unawaited(refresh());
    ref.onDispose(() => _retry?.cancel());
    // Режим включили — сведения нужны сейчас, даже если прошлые попытки кончились.
    ref.listen(settingsProvider.select((s) => s.pushWake), (_, on) {
      if (on && state == null) unawaited(refresh());
    });
    unawaited(refresh());
    return null;
  }

  Future<void> refresh() async {
    _retry?.cancel();
    _attempt = 0;
    await _ask();
  }

  Future<void> _ask() async {
    PushInfo? info;
    try {
      info = await ref.read(callKeeperProvider).pushInfo().timeout(const Duration(seconds: 6));
    } catch (_) {
      info = null; // телефон не ответил — считаем, что push нет
    }
    if (!ref.mounted) return;
    if (info != state) state = info;
    // Повторяем, только если режим выбран: там, где push нет вовсе, спрашивать снова незачем.
    if (info == null && ref.read(settingsProvider).pushWake && _attempt < retryAfter.length) {
      _retry = Timer(retryAfter[_attempt++], () => unawaited(_ask()));
    }
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

  /// Не засыпаем, пока АТС не подтвердила регистрацию: иначе она может не знать нынешнего адреса для push
  /// (после перезагрузки телефона сеть появляется не сразу). Но и ждать вечно нельзя — это батарея.
  static const registerPatience = Duration(minutes: 2);

  /// Как часто проверять, появилась ли регистрация, пока её ждём.
  static const _recheck = Duration(seconds: 5);

  /// Небольшая пауза перед остановкой фоновой службы после ухода со связи.
  static const _farewell = Duration(milliseconds: 300);

  bool _visible = false;
  DateTime _awakeUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// С какого момента приложение пытается выйти на связь в нынешнем периоде бодрствования.
  DateTime _awakeSince = DateTime.fromMillisecondsSinceEpoch(0);
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
    _awakeSince = clock.now();
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
    // Звонок закончился — ещё немного остаёмся на связи: могут перезвонить. Заодно применяем смену режима
    // или адреса для push, если она пришла во время звонка (тогда связь трогать было нельзя).
    void callChanged({required bool ended}) {
      if (ended) {
        _stayAwake(linger);
        unawaited(ref.read(sessionProvider.notifier).usePush(ref.read(pushModeProvider)));
      }
      _evaluate();
    }

    ref.listen(callProvider, (previous, next) => callChanged(ended: previous != null && next == null));
    ref.listen(otherCallProvider, (previous, next) => callChanged(ended: previous != null && next == null));
    // Регистрация появилась или пропала — возможно, теперь можно (или уже нельзя) засыпать.
    ref.listen(linkProvider, (_, _) => _evaluate());
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
        _awakeSince = now;
        unawaited(ref.read(sessionProvider.notifier).wake());
      }
      if (!_visible && !inCall) {
        _timer = Timer(_awakeUntil.difference(now) + const Duration(milliseconds: 50), _evaluate);
      }
      return;
    }
    if (state || _goingToSleep) return;
    if (!ref.read(linkProvider).isOnline && now.difference(_awakeSince) < registerPatience) {
      // Регистрация ещё не подтверждена — подождём её, прежде чем уходить со связи.
      _timer = Timer(_recheck, _evaluate);
      return;
    }
    _goingToSleep = true;
    unawaited(_sleep());
  }

  Future<void> _sleep() async {
    _engineAsleep = true;
    // Движок сам дожидается от АТС подтверждения, что регистрация снята.
    await ref.read(sessionProvider.notifier).sleep();
    await Future<void>.delayed(_farewell);
    // За это время приложение могли открыть или разбудить — тогда спать уже не нужно.
    if (!ref.mounted || !_goingToSleep) return;
    _goingToSleep = false;
    state = true;
  }
}

final pushAsleepProvider = NotifierProvider<PushSleepController, bool>(PushSleepController.new);

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/call_keeper.dart';
import '../sip/call_engine.dart';
import 'call.dart';
import 'session.dart';
import 'settings.dart';

/// Умеет ли этот телефон вести звонки приложения в своей системе звонков. Без этого переключатель
/// «Системные звонки» в настройках не показываем.
final systemCallsSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(callKeeperProvider).systemCallsSupported(),
);

/// Устройства звука, как их видит система звонков телефона. Пока система ведёт хотя бы один наш звонок
/// и назвала устройства, движок берёт список отсюда и сюда же передаёт выбор человека ([AudioRouter]).
class SystemAudio extends ChangeNotifier implements AudioRouter {
  SystemAudio(this._keeper);

  final CallKeeper _keeper;

  // Что система сказала про каждый звонок; последний сказавший — в конце.
  final _byCall = <int, (List<AudioRoute>, AudioKind?)>{};

  @override
  List<AudioRoute>? get routes => _byCall.isEmpty ? null : _byCall.values.last.$1;

  @override
  AudioKind? get current => _byCall.isEmpty ? null : _byCall.values.last.$2;

  /// Система назвала устройства звонка [id] и выбранное сейчас.
  void update(int id, List<AudioRoute> routes, AudioKind? current) {
    // Пустой список — система ещё не разобралась; ждём настоящего.
    if (routes.isEmpty) return;
    _byCall.remove(id);
    _byCall[id] = (routes, current);
    notifyListeners();
  }

  /// Система больше не ведёт звонок [id].
  void forget(int id) {
    if (_byCall.remove(id) != null) notifyListeners();
  }

  @override
  void select(AudioKind kind) {
    if (_byCall.isEmpty) return;
    _keeper.systemCallRoute(_byCall.keys.last, kind);
  }
}

/// Что уже сообщено системе про один звонок.
class _Reported {
  _Reported(this.incoming);

  final bool incoming;

  /// null — ещё не соединён; иначе — на удержании или нет.
  bool? held;

  bool get answered => held != null;
}

/// Пробный режим «Системные звонки»: пересказывает системе звонков телефона, что происходит со звонками
/// приложения, и выполняет её команды (кнопка гарнитуры, машина, часы, пришедший сотовый звонок).
///
/// Сами звонки по-прежнему ведёт [CallController]; этот класс только наблюдает за ним. Если режим выключен
/// или телефон отказал, всё работает как раньше.
class _SystemCalls {
  _SystemCalls(this._ref, this._keeper) : audio = SystemAudio(_keeper);

  final Ref _ref;
  final CallKeeper _keeper;
  final SystemAudio audio;

  final _reported = <int, _Reported>{};
  bool _scheduled = false;

  /// Сверяемся не сразу, а когда текущий и второй звонок оба обновились: при переключении между двумя
  /// разговорами они меняются по очереди, и в промежутке один из них на миг не числится нигде —
  /// системе нельзя сообщать, будто он закончился.
  void schedule() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (_ref.mounted) _sync();
    });
  }

  void _sync() {
    final account = _ref.read(sessionProvider);
    final enabled = _ref.read(settingsProvider).systemCalls && account != null && !account.isDemo;
    final live = <int, CallInfo>{};
    for (final call in [_ref.read(callProvider), _ref.read(otherCallProvider)]) {
      if (call != null) live[call.id] = call;
    }

    for (final id in _reported.keys.where((id) => !live.containsKey(id)).toList()) {
      final was = _reported.remove(id)!;
      _keeper.systemCallEnd(id, was.incoming && !was.answered ? SystemCallEnd.missed : SystemCallEnd.local);
    }

    for (final call in live.values) {
      var known = _reported[call.id];
      if (known == null) {
        // Режим выключен — новых звонков системе не сообщаем; уже сообщённые доводим до конца.
        if (!enabled) continue;
        known = _reported[call.id] = _Reported(call.incoming);
        _keeper.systemCallStart(id: call.id, number: call.number, name: call.name, incoming: call.incoming);
      }
      final held = call.phase == CallPhase.active ? call.held : null;
      if (held != null && held != known.held) {
        known.held = held;
        _keeper.systemCallState(call.id, held: held);
      }
    }
  }

  /// Команда системы для звонка [id]. Выполняем её теми же действиями, что и кнопки на экране.
  void command(int id, SystemCallAction action) {
    final call = _ref.read(callProvider);
    final other = _ref.read(otherCallProvider);
    final calls = _ref.read(callProvider.notifier);
    final current = call != null && call.id == id;
    final second = other != null && other.id == id;
    switch (action) {
      case SystemCallAction.answer:
        if (current && call.phase == CallPhase.incoming) {
          calls.accept();
        } else if (second && other.phase == CallPhase.incoming) {
          calls.acceptOther();
        }
      case SystemCallAction.hangUp:
        if (current) {
          calls.hangUp();
        } else if (second && other.phase == CallPhase.incoming) {
          calls.rejectOther();
        }
      // Удержанный второй разговор по команде системы не завершаем: такой кнопки нет и на экране.
      // Система перестанет его вести, а в приложении он останется.
      case SystemCallAction.hold:
        if (current && call.phase == CallPhase.active && !call.held) calls.toggleHold();
      case SystemCallAction.unhold:
        if (current && call.phase == CallPhase.active && call.held) {
          calls.toggleHold();
        } else if (second && other.phase == CallPhase.active && other.held) {
          calls.swap();
        }
    }
  }
}

/// Достаточно один раз прочитать этот провайдер — дальше он работает сам (как [presenceProvider]).
final systemCallsProvider = Provider<void>((ref) {
  final keeper = ref.watch(callKeeperProvider);
  final system = _SystemCalls(ref, keeper);
  keeper.onSystemCall = system.command;
  keeper.onSystemRoutes = system.audio.update;
  keeper.onSystemCallGone = system.audio.forget;

  ref.listen(callProvider, (_, _) => system.schedule());
  ref.listen(otherCallProvider, (_, _) => system.schedule());
  ref.listen(settingsProvider.select((s) => s.systemCalls), (_, _) => system.schedule());
  // Движку — у кого спрашивать устройства звука. Движок меняется при входе и выходе из учётной записи.
  ref.listen(engineProvider, (_, engine) => engine?.audioRouter = system.audio, fireImmediately: true);
  system.schedule();
});

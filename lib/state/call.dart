import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import '../sip/call_engine.dart';
import '../sip/demo_engine.dart';
import 'contacts.dart';
import 'history.dart';
import 'session.dart';
import 'settings.dart';

export '../sip/call_engine.dart' show CallFailure, CallFailureEvent, CallInfo, CallPhase;

/// Текущий звонок (null — звонка нет).
///
/// Экраны работают только с этим классом. Сам звонок ведёт движок ([CallEngine]):
/// настоящий SIP или имитация — экранам всё равно.
class CallController extends Notifier<CallInfo?> {
  CallEngine? _engine;

  // Что нужно помнить о звонке, чтобы после его конца записать строку в историю.
  CallInfo? _first;
  DateTime? _answeredAt;
  String? _lastDialed;

  @override
  CallInfo? build() {
    final engine = ref.watch(engineProvider);
    _engine = engine;
    _first = null;
    _answeredAt = null;
    if (engine == null) return null;
    void sync() {
      var next = engine.call.value;
      // Имени от АТС нет — берём из своих контактов.
      if (next != null && next.name == null) {
        final known = ref.read(contactsProvider.notifier).nameOf(next.number);
        if (known != null) next = next.withName(known);
      }
      // «Не беспокоить»: входящий не показываем и не звоним, звонящему — «занято». В историю он попадёт как пропущенный.
      if (next != null && next.phase == CallPhase.incoming && state == null && ref.read(settingsProvider).dnd) {
        _track(next);
        engine.reject();
        return;
      }
      _track(next);
      state = next;
    }

    engine.call.addListener(sync);
    ref.onDispose(() => engine.call.removeListener(sync));
    return engine.call.value;
  }

  void _track(CallInfo? next) {
    if (next != null) {
      _first ??= next;
      if (next.phase == CallPhase.active) _answeredAt ??= next.since ?? DateTime.now();
      return;
    }
    final first = _first;
    if (first == null) return;
    final answered = _answeredAt;
    _first = null;
    _answeredAt = null;
    final now = DateTime.now();
    ref
        .read(historyProvider.notifier)
        .add(
          HistoryEntry(
            name: first.name,
            number: first.number,
            kind: !first.incoming ? CallKind.outgoing : (answered == null ? CallKind.missed : CallKind.incoming),
            seconds: answered == null ? 0 : now.difference(answered).inSeconds,
            at: now,
          ),
        );
  }

  void dial(String number, {String? name}) {
    if (number.isEmpty) return;
    _lastDialed = number;
    _engine?.dial(number, name: name ?? ref.read(contactsProvider.notifier).nameOf(number));
  }

  /// Последний набранный номер — для повтора кнопкой вызова при пустом поле.
  String? get lastDialed {
    if (_lastDialed != null) return _lastDialed;
    for (final e in ref.read(historyProvider)) {
      if (e.kind == CallKind.outgoing && e.number.isNotEmpty) return e.number;
    }
    return null;
  }

  /// Перевести собеседника на другой номер.
  void transfer(String target) => _engine?.transfer(target);

  /// Показывает входящий звонок — только в демонстрации, чтобы посмотреть экран.
  void simulateIncoming({required String number, String? name}) {
    final engine = _engine;
    if (engine is DemoEngine) engine.simulateIncoming(number: number, name: name);
  }

  void accept() => _engine?.accept();

  void hangUp() => _engine?.hangUp();

  void toggleMute() => _engine?.setMuted(!(state?.muted ?? false));

  void toggleSpeaker() => _engine?.setSpeaker(!(state?.speaker ?? false));

  void toggleHold() => _engine?.setHeld(!(state?.held ?? false));

  void sendDtmf(String tone) => _engine?.sendDtmf(tone);
}

final callProvider = NotifierProvider<CallController, CallInfo?>(CallController.new);

/// Нажата ли «Без звука» у текущего входящего. Сбрасывается, как только звонок перестаёт быть входящим.
class RingSilenced extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(callProvider, (_, next) {
      if (next?.phase != CallPhase.incoming) state = false;
    });
    return false;
  }

  void silence() => state = true;
}

final ringSilencedProvider = NotifierProvider<RingSilenced, bool>(RingSilenced.new);

/// Сбои звонков («занято», «нет связи») — их показывает всплывающая строка.
final callFailureProvider = StreamProvider<CallFailureEvent>(
  (ref) => ref.watch(engineProvider)?.failures ?? const Stream.empty(),
);

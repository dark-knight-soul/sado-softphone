import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import '../l10n/strings.dart';
import '../platform/call_keeper.dart';
import '../sip/call_engine.dart';
import '../sip/demo_engine.dart';
import 'contacts.dart';
import 'history.dart';
import 'session.dart';
import 'settings.dart';

export '../sip/call_engine.dart' show AudioKind, AudioRoute, CallFailure, CallFailureEvent, CallInfo, CallPhase;

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

  // Кто звонил и не дозвонился с тех пор, как человек последний раз видел окно приложения (новые — в конце).
  final _missed = <String>[];

  /// Человек сам отклонил текущий входящий. В истории такой звонок остаётся «пропущенным»,
  /// но уведомлять о нём незачем: человек о нём и так знает.
  bool _declinedByUser = false;

  @override
  CallInfo? build() {
    final engine = ref.watch(engineProvider);
    _engine = engine;
    _first = null;
    _answeredAt = null;
    _missed.clear();
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
    final missed = first.incoming && answered == null;
    ref
        .read(historyProvider.notifier)
        .add(
          HistoryEntry(
            name: first.name,
            number: first.number,
            kind: !first.incoming ? CallKind.outgoing : (missed ? CallKind.missed : CallKind.incoming),
            seconds: answered == null ? 0 : now.difference(answered).inSeconds,
            at: now,
          ),
        );
    if (missed && !_declinedByUser) _notifyMissed(first);
    _declinedByUser = false;
  }

  /// Уведомление о пропущенном в шторке: одно на все звонки, в нём число и до трёх последних звонивших.
  /// Показывает его телефон, и только когда окна приложения нет на экране (см. MissedCalls.kt).
  void _notifyMissed(CallInfo call) {
    // В демонстрации звонки ненастоящие — шторку не трогаем.
    if (ref.read(sessionProvider)?.isDemo ?? true) return;
    final s = S.byCode(ref.read(settingsProvider).lang ?? PlatformDispatcher.instance.locale.languageCode);
    _missed.add(s.caller(call.name, call.number));
    final recent = _missed.reversed.take(3).toList();
    ref
        .read(callKeeperProvider)
        .missed(
          title: _missed.length == 1 ? s.missedCallTitle : s.missedCallsTitle(_missed.length),
          text: _missed.length == 1 ? _missed.single : recent.join(', '),
        );
  }

  /// Окно приложения показано (или телефон отказался показывать уведомление): счёт пропущенных начинается заново.
  void resetMissed() => _missed.clear();

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

  void hangUp() {
    if (state?.phase == CallPhase.incoming) _declinedByUser = true;
    _engine?.hangUp();
  }

  void toggleMute() => _engine?.setMuted(!(state?.muted ?? false));

  void toggleSpeaker() => _engine?.setSpeaker(!(state?.speaker ?? false));

  /// Доступные устройства звука (пусто, если движка нет).
  ValueListenable<List<AudioRoute>> get routes => _engine?.routes ?? ValueNotifier<List<AudioRoute>>(const []);

  void selectRoute(AudioRoute route) => _engine?.setRoute(route);

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

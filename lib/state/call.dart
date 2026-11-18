import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import '../l10n/strings.dart';
import '../platform/call_keeper.dart';
import '../sip/call_engine.dart';
import '../sip/demo_engine.dart';
import 'contacts.dart';
import 'history.dart';
import 'pbx_features.dart';
import 'session.dart';
import 'settings.dart';

export '../sip/call_engine.dart' show AudioKind, AudioRoute, CallFailure, CallFailureEvent, CallInfo, CallPhase;

/// Имя из своих контактов, если АТС имени не прислала.
CallInfo? _named(Ref ref, CallInfo? call) {
  if (call == null || call.name != null) return call;
  final known = ref.read(contactsProvider.notifier).nameOf(call.number);
  return known == null ? call : call.withName(known);
}

/// Что нужно помнить о звонке, чтобы после его конца записать строку в историю.
class _Tracked {
  _Tracked(this.first);

  /// Каким звонок появился (имя, номер, входящий или нет).
  final CallInfo first;

  /// Когда начался разговор; null — не ответили.
  DateTime? answeredAt;
}

/// Текущий звонок (null — звонка нет). Если звонков два, это тот, с которым идёт разговор;
/// второй (ожидающий ответа или на удержании) — в [otherCallProvider].
///
/// Экраны работают только с этим классом. Сам звонок ведёт движок ([CallEngine]):
/// настоящий SIP или имитация — экранам всё равно.
class CallController extends Notifier<CallInfo?> {
  CallEngine? _engine;

  // Каждый живой звонок (текущий и второй) по его номеру CallInfo.id — у каждого своя строка в истории.
  final _tracked = <int, _Tracked>{};
  String? _lastDialed;

  // Кто звонил и не дозвонился с тех пор, как человек последний раз видел окно приложения (новые — в конце).
  final _missed = <String>[];

  /// Входящие, которые человек отклонил сам. В истории такой звонок остаётся «пропущенным»,
  /// но уведомлять о нём незачем: человек о нём и так знает.
  final _declinedByUser = <int>{};

  @override
  CallInfo? build() {
    final engine = ref.watch(engineProvider);
    _engine = engine;
    _tracked.clear();
    _declinedByUser.clear();
    _missed.clear();
    if (engine == null) return null;
    void sync() {
      final next = _named(ref, engine.call.value);
      // «Не беспокоить»: входящий не показываем и не звоним, звонящему — «занято». В историю он попадёт как пропущенный.
      if (next != null && next.phase == CallPhase.incoming && state == null && ref.read(settingsProvider).dnd) {
        _observe(next);
        engine.reject();
        return;
      }
      _observe(next);
      state = next;
      _sweep(engine);
    }

    void syncOther() {
      final next = _named(ref, engine.other.value);
      final fresh = next != null && !_tracked.containsKey(next.id);
      _observe(next);
      // «Не беспокоить» действует и на второй звонок: отклоняем сразу, в истории он пропущенный.
      if (fresh && next.phase == CallPhase.incoming && ref.read(settingsProvider).dnd) {
        engine.rejectOther(busy: true);
        return;
      }
      _sweep(engine);
    }

    engine.call.addListener(sync);
    engine.other.addListener(syncOther);
    ref.onDispose(() {
      engine.call.removeListener(sync);
      engine.other.removeListener(syncOther);
    });
    return engine.call.value;
  }

  /// Запоминает звонок, пока он жив: каким появился и когда на него ответили.
  void _observe(CallInfo? call) {
    if (call == null) return;
    final t = _tracked.putIfAbsent(call.id, () => _Tracked(call));
    if (call.phase == CallPhase.active) t.answeredAt ??= call.since ?? DateTime.now();
  }

  /// Пишет в историю звонки, которых больше нет ни в текущем, ни во втором.
  ///
  /// Пока звонки меняются местами, движок обновляет два поля по очереди, и один из звонков может на миг
  /// пропасть из обоих. Поэтому, если какой-то звонок ещё жив, проверку откладываем до конца этих обновлений
  /// (они идут подряд, без пауз). Если звонков не осталось вовсе — пишем сразу, как и раньше с одним звонком.
  void _sweep(CallEngine engine) {
    if (engine.call.value == null && engine.other.value == null) {
      _finishGone(engine);
    } else if (!_allLive(engine)) {
      scheduleMicrotask(() {
        if (ref.mounted && identical(_engine, engine)) _finishGone(engine);
      });
    }
  }

  bool _allLive(CallEngine engine) =>
      _tracked.keys.every((id) => engine.call.value?.id == id || engine.other.value?.id == id);

  void _finishGone(CallEngine engine) {
    final live = {engine.call.value?.id, engine.other.value?.id};
    for (final id in _tracked.keys.where((id) => !live.contains(id)).toList()) {
      _finish(id, _tracked.remove(id)!);
    }
  }

  void _finish(int id, _Tracked t) {
    final first = t.first;
    final answered = t.answeredAt;
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
    final declined = _declinedByUser.remove(id);
    if (missed && !declined) _notifyMissed(first);
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
    final c = state;
    if (c != null && c.phase == CallPhase.incoming) _declinedByUser.add(c.id);
    _engine?.hangUp();
  }

  /// Ответить на второй звонок: текущий разговор уходит на удержание.
  void acceptOther() => _engine?.acceptOther();

  /// Отклонить второй звонок. Как и обычный отклонённый входящий, в истории он пропущенный, но без уведомления.
  void rejectOther() {
    final o = _engine?.other.value;
    if (o == null || o.phase != CallPhase.incoming) return;
    _declinedByUser.add(o.id);
    _engine?.rejectOther();
  }

  /// Поменять местами текущий разговор и разговор на удержании.
  void swap() => _engine?.swap();

  /// «Сначала поговорить»: текущий разговор — на удержание, звоним на [number]. Потом [connectCalls] соединит их.
  void consult(String number) {
    if (number.isEmpty) return;
    _engine?.consult(number, name: ref.read(contactsProvider.notifier).nameOf(number));
  }

  /// Соединить текущего собеседника с удержанным; оба звонка уходят с телефона.
  void connectCalls() => _engine?.connectCalls();

  /// «Объединить»: оба разговора уходят во временную комнату конференции на АТС, и этот телефон входит
  /// туда же. Работает, только если АТС сообщила, что умеет это ([pbxFeaturesProvider]).
  void conference() {
    final features = ref.read(pbxFeaturesProvider);
    if (!features.canConference) return;
    final s = S.byCode(ref.read(settingsProvider).lang ?? PlatformDispatcher.instance.locale.languageCode);
    _engine?.conference(features.newConferenceRoom(), name: s.conference);
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

/// Второй звонок рядом с текущим: ожидает ответа ([CallPhase.incoming]) или на удержании; null — его нет.
/// Команды для него — у [CallController] (acceptOther, rejectOther, swap); историю тоже ведёт он.
class OtherCallController extends Notifier<CallInfo?> {
  @override
  CallInfo? build() {
    final engine = ref.watch(engineProvider);
    if (engine == null) return null;
    // Историю и «Не беспокоить» для второго звонка ведёт CallController — он должен слушать движок.
    ref.watch(callProvider.notifier);
    CallInfo? shown() {
      final next = _named(ref, engine.other.value);
      // При «Не беспокоить» новый второй звонок отклоняется сразу — карточку не показываем даже на миг.
      if (next != null && next.phase == CallPhase.incoming && ref.read(settingsProvider).dnd) return null;
      return next;
    }

    void sync() => state = shown();
    engine.other.addListener(sync);
    ref.onDispose(() => engine.other.removeListener(sync));
    return shown();
  }
}

final otherCallProvider = NotifierProvider<OtherCallController, CallInfo?>(OtherCallController.new);

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

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/account.dart';

/// Состояние связи с АТС.
enum LinkState { offline, connecting, online, failed }

/// Почему связь не установилась.
enum LinkError {
  /// Сервер ответил, но номер или пароль не подошли.
  auth,

  /// До сервера не достучались.
  network,
  other,
}

@immutable
class LinkStatus {
  const LinkStatus(this.state, [this.error]);

  static const offline = LinkStatus(LinkState.offline);
  static const connecting = LinkStatus(LinkState.connecting);
  static const online = LinkStatus(LinkState.online);

  final LinkState state;
  final LinkError? error;

  bool get isOnline => state == LinkState.online;

  @override
  bool operator ==(Object other) => other is LinkStatus && other.state == state && other.error == error;

  @override
  int get hashCode => Object.hash(state, error);

  @override
  String toString() => 'LinkStatus(${state.name}${error == null ? '' : ', ${error!.name}'})';
}

/// Оставляет в номере только то, что может быть номером или именем абонента на АТС: буквы, цифры и + * # . _ -.
/// Всё остальное («@», «:», «;», пробелы, скобки) выбрасывается: иначе строка из контакта вида
/// «100@чужой-сервер» превратилась бы в адрес на постороннем сервере.
String dialTarget(String raw) => raw.replaceAll(RegExp(r'[^A-Za-z0-9+*#._-]'), '');

enum CallPhase { incoming, outgoing, active }

@immutable
class CallInfo {
  const CallInfo({
    required this.phase,
    required this.number,
    required this.incoming,
    this.name,
    this.since,
    this.muted = false,
    this.speaker = false,
    this.held = false,
    this.secure = false,
  });

  final CallPhase phase;
  final String number;

  /// Звонок пришёл нам (а не мы звоним). Не меняется, когда входящий становится разговором.
  final bool incoming;
  final String? name;

  /// Когда начался разговор (для таймера); null, пока идёт вызов.
  final DateTime? since;
  final bool muted;
  final bool speaker;
  final bool held;

  /// Звонок зашифрован целиком. Надпись «Защищённый звонок» показываем только при true.
  final bool secure;

  /// Тот же звонок, но с именем (подставляется из контактов).
  CallInfo withName(String? value) => CallInfo(
    phase: phase,
    number: number,
    incoming: incoming,
    name: value,
    since: since,
    muted: muted,
    speaker: speaker,
    held: held,
    secure: secure,
  );

  CallInfo copyWith({CallPhase? phase, DateTime? since, bool? muted, bool? speaker, bool? held}) => CallInfo(
    phase: phase ?? this.phase,
    number: number,
    incoming: incoming,
    name: name,
    since: since ?? this.since,
    muted: muted ?? this.muted,
    speaker: speaker ?? this.speaker,
    held: held ?? this.held,
    secure: secure,
  );

  @override
  bool operator ==(Object other) =>
      other is CallInfo &&
      other.phase == phase &&
      other.number == number &&
      other.incoming == incoming &&
      other.name == name &&
      other.since == since &&
      other.muted == muted &&
      other.speaker == speaker &&
      other.held == held &&
      other.secure == secure;

  @override
  int get hashCode => Object.hash(phase, number, incoming, name, since, muted, speaker, held, secure);
}

/// Почему звонок не состоялся — чтобы показать человеку понятную причину.
enum CallFailure { busy, rejected, noAnswer, unavailable, micDenied, offline, other }

/// Одно событие «звонок не удался». Отдельный объект, чтобы два одинаковых сбоя подряд
/// не слиплись в один.
class CallFailureEvent {
  CallFailureEvent(this.kind);

  final CallFailure kind;
}

/// Движок звонков. Экраны и состояние приложения знают только этот класс;
/// что внутри — имитация или настоящий SIP — им всё равно.
abstract class CallEngine {
  /// Связь с АТС.
  final ValueNotifier<LinkStatus> link = ValueNotifier(LinkStatus.offline);

  /// Текущий звонок; null — звонка нет.
  final ValueNotifier<CallInfo?> call = ValueNotifier(null);

  final StreamController<CallFailureEvent> _failures = StreamController.broadcast();

  /// Сбои звонков («занято», «нет доступа к микрофону» и т. п.).
  Stream<CallFailureEvent> get failures => _failures.stream;

  @protected
  void reportFailure(CallFailure kind) {
    if (!_failures.isClosed) _failures.add(CallFailureEvent(kind));
  }

  /// Подключается к АТС и возвращает первый определённый итог: «на связи» или причину отказа.
  ///
  /// [keepTrying] — не сдаваться, если сервер недоступен (так подключаемся при запуске приложения
  /// с уже сохранённой учётной записью). При входе с экрана входа — false: нужен быстрый ответ.
  Future<LinkStatus> connect(Account account, String password, {bool keepTrying = false});

  void dial(String number, {String? name});

  void accept();

  void hangUp();

  /// Отклонить входящий так, чтобы звонящий услышал «занято» (режим «Не беспокоить»).
  void reject();

  /// Перевести собеседника на другой номер; наш звонок после этого завершается.
  void transfer(String target);

  void setMuted(bool muted);

  void setHeld(bool held);

  void setSpeaker(bool on);

  /// Донабор цифр во время разговора (например, в голосовом меню).
  void sendDtmf(String tone);

  @mustCallSuper
  void dispose() {
    _failures.close();
    link.dispose();
    call.dispose();
  }
}

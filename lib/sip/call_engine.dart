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

/// Куда может идти звук разговора.
enum AudioKind { earpiece, speaker, bluetooth, wired }

/// Одно из доступных устройств вывода звука.
@immutable
class AudioRoute {
  const AudioRoute(this.kind, [this.label]);

  final AudioKind kind;

  /// Название от телефона (например, имя Bluetooth-гарнитуры); null — названия нет.
  final String? label;

  @override
  bool operator ==(Object other) => other is AudioRoute && other.kind == kind && other.label == label;

  @override
  int get hashCode => Object.hash(kind, label);

  @override
  String toString() => 'AudioRoute(${kind.name}${label == null ? '' : ', $label'})';
}

@immutable
class CallInfo {
  const CallInfo({
    required this.phase,
    required this.number,
    required this.incoming,
    this.name,
    this.since,
    this.muted = false,
    this.route = AudioKind.earpiece,
    this.held = false,
    this.secure = false,
    this.id = 0,
  });

  /// Номер звонка внутри движка: отличает два одновременных звонка друг от друга
  /// (по нему, например, история понимает, какой из них закончился). Не меняется за всю жизнь звонка.
  final int id;

  final CallPhase phase;
  final String number;

  /// Звонок пришёл нам (а не мы звоним). Не меняется, когда входящий становится разговором.
  final bool incoming;
  final String? name;

  /// Когда начался разговор (для таймера); null, пока идёт вызов.
  final DateTime? since;
  final bool muted;
  final bool held;

  /// Куда сейчас идёт звук.
  final AudioKind route;

  /// Включена ли громкая связь (звук идёт в динамик). Остальное — в [route].
  bool get speaker => route == AudioKind.speaker;

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
    route: route,
    held: held,
    secure: secure,
    id: id,
  );

  /// [speaker] — короткий путь для «громкая связь вкл/выкл»: сводится к [route]; если задан и он, главнее [route].
  CallInfo copyWith({CallPhase? phase, DateTime? since, bool? muted, bool? speaker, bool? held, AudioKind? route}) =>
      CallInfo(
        phase: phase ?? this.phase,
        number: number,
        incoming: incoming,
        name: name,
        since: since ?? this.since,
        muted: muted ?? this.muted,
        route: speaker != null ? (speaker ? AudioKind.speaker : AudioKind.earpiece) : (route ?? this.route),
        held: held ?? this.held,
        secure: secure,
        id: id,
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
      other.route == route &&
      other.held == held &&
      other.secure == secure &&
      other.id == id;

  @override
  int get hashCode => Object.hash(phase, number, incoming, name, since, muted, route, held, secure, id);
}

/// Почему звонок не состоялся — чтобы показать человеку понятную причину.
/// [transfer] — АТС не соединила двух собеседников (см. [CallEngine.connectCalls]); оба звонка при этом остаются.
enum CallFailure { busy, rejected, noAnswer, unavailable, micDenied, offline, other, transfer }

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

  /// Текущий звонок — тот, с которым сейчас разговариваем и к которому относятся все кнопки экрана; null — звонка нет.
  final ValueNotifier<CallInfo?> call = ValueNotifier(null);

  /// Второй звонок рядом с текущим; null — его нет. Фаза [CallPhase.incoming] — звонит, пока идёт разговор
  /// («ожидает ответа»), [CallPhase.active] с `held: true` — разговор на удержании.
  ///
  /// Порядок обновления важен: живой звонок не должен ни на миг пропадать из обоих полей сразу,
  /// иначе история посчитает его законченным. Поэтому, когда текущий звонок кончается, а второй
  /// занимает его место, движок сначала пишет второй в [call] и только потом очищает [other].
  final ValueNotifier<CallInfo?> other = ValueNotifier(null);

  int _lastCallId = 0;

  /// Новый номер звонка для [CallInfo.id] — свой у каждого звонка, пока живёт движок.
  @protected
  int nextCallId() => ++_lastCallId;

  /// Устройства вывода звука, доступные сейчас (пусто, пока звонка нет или платформа их не назвала).
  final ValueNotifier<List<AudioRoute>> routes = ValueNotifier(const []);

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

  /// Выбрать, куда выводить звук (из [routes]).
  void setRoute(AudioRoute route);

  /// Донабор цифр во время разговора (например, в голосовом меню).
  void sendDtmf(String tone);

  /// Ответить на второй звонок: текущий разговор уходит на удержание, второй становится текущим.
  void acceptOther();

  /// Отклонить второй звонок, пока он ждёт ответа; текущий разговор не трогаем.
  /// [busy] — звонящий слышит «занято», как при [reject] («Не беспокоить»); иначе — «отклонено», как при «Отклонить».
  void rejectOther({bool busy = false});

  /// Поменять местами текущий разговор и разговор на удержании.
  void swap();

  /// «Сначала поговорить» перед переводом: текущий разговор уходит на удержание, и начинается второй, исходящий
  /// вызов на [number] — он становится текущим. Работает, только пока идёт ровно один соединённый звонок;
  /// это единственный способ набрать второй звонок (обычный [dial] во время звонка ничего не делает).
  /// Если второй вызов не состоялся или его завершили, удержанный звонок возвращается сам (как при двух звонках).
  void consult(String number, {String? name});

  /// Соединить двух собеседников друг с другом (перевод с консультацией) и убрать оба звонка с этого телефона.
  /// Нужны два соединённых звонка: текущий и удержанный. Если АТС отказала, оба звонка остаются как были,
  /// а в [failures] приходит [CallFailure.transfer].
  void connectCalls();

  @mustCallSuper
  void dispose() {
    _failures.close();
    link.dispose();
    call.dispose();
    other.dispose();
    routes.dispose();
  }
}

import '../data/push_info.dart';

import 'dart:async';

import '../state/account.dart';
import 'call_engine.dart';

/// Имитация звонков без АТС: «связь» есть сразу, «собеседник» отвечает через две секунды.
/// Нужна для демонстрации (сервер `demo`) и для тестов.
class DemoEngine extends CallEngine {
  /// [extraRoutes] — дополнительные устройства звука (гарнитура и т. п.); нужны, чтобы проверить выбор в тестах.
  DemoEngine({this.answerAfter = const Duration(seconds: 2), List<AudioRoute> extraRoutes = const []}) {
    routes.value = [const AudioRoute(AudioKind.earpiece), const AudioRoute(AudioKind.speaker), ...extraRoutes];
  }

  final Duration answerAfter;

  /// За какими номерами просили следить — для тестов. Сами статусы тест пишет прямо в [presence].
  Set<String> watchedNumbers = const {};

  @override
  void watchPresence(Set<String> numbers) => watchedNumbers = numbers;
  Timer? _answerTimer;

  /// Сколько входящих имитация отклонила «занято» (третий звонок, второй во время вызова) — для тестов.
  int busyRejected = 0;

  /// «АТС отказывается соединять»: [connectCalls] не соединяет, а сообщает о сбое — чтобы проверить это в тестах.
  bool failConnect = false;

  /// С какими сведениями о push подключались (по одному на каждое подключение) и сколько раз «засыпали» — для тестов.
  final connectedWith = <PushInfo?>[];
  int sleeps = 0;

  @override
  Future<void> sleep() async {
    if (call.value != null || other.value != null) return;
    sleeps++;
    link.value = LinkStatus.offline;
  }

  @override
  Future<LinkStatus> connect(Account account, String password, {bool keepTrying = false, PushInfo? push}) async {
    connectedWith.add(push);
    link.value = LinkStatus.online;
    return LinkStatus.online;
  }

  @override
  void dial(String number, {String? name}) {
    if (call.value != null || number.isEmpty) return;
    // В имитации отмечаем звонок защищённым, чтобы был виден весь экран.
    call.value = CallInfo(
      phase: CallPhase.outgoing,
      number: number,
      name: name,
      incoming: false,
      secure: true,
      id: nextCallId(),
    );
    _answerTimer = Timer(answerAfter, () {
      final c = call.value;
      if (c?.phase == CallPhase.outgoing) {
        call.value = c!.copyWith(phase: CallPhase.active, since: DateTime.now());
      }
    });
  }

  /// Показывает входящий звонок (кнопка в настройках, чтобы посмотреть экран).
  ///
  /// Во время разговора входящий становится вторым, ожидающим ответа. Так же, как настоящий движок,
  /// имитация отвечает «занято» третьему звонку и второму, пока первый ещё не соединился.
  void simulateIncoming({required String number, String? name}) {
    final info = CallInfo(
      phase: CallPhase.incoming,
      number: number,
      name: name,
      incoming: true,
      secure: true,
      id: nextCallId(),
    );
    final c = call.value;
    if (c == null) {
      call.value = info;
    } else if (c.phase == CallPhase.active && other.value == null) {
      other.value = info;
    } else {
      busyRejected++;
    }
  }

  /// Второй собеседник положил трубку: ожидающий не дождался ответа или удержанный завершил разговор.
  void otherHangsUp() => other.value = null;

  /// Текущий вызов не удался на той стороне (занято, отклонили, нет ответа). Как и в настоящем движке,
  /// удержанный звонок, если он есть, занимает место текущего и снимается с удержания.
  void currentFails(CallFailure kind) {
    if (call.value == null) return;
    hangUp();
    reportFailure(kind);
  }

  @override
  void accept() {
    final c = call.value;
    if (c?.phase != CallPhase.incoming) return;
    call.value = c!.copyWith(phase: CallPhase.active, since: DateTime.now());
  }

  @override
  void hangUp() {
    _answerTimer?.cancel();
    final o = other.value;
    if (o == null) {
      call.value = null;
      return;
    }
    // Второй звонок занимает место текущего: удержанный снимается с удержания, звук остаётся там же,
    // ожидающий снова звонит как обычный входящий. Сначала [call], потом [other] — см. CallEngine.other.
    final route = call.value?.route ?? o.route;
    call.value = o.phase == CallPhase.active ? o.copyWith(held: false, route: route) : o;
    other.value = null;
  }

  @override
  void acceptOther() {
    final c = call.value;
    final o = other.value;
    if (c == null || o?.phase != CallPhase.incoming || c.phase != CallPhase.active) return;
    // Как в настоящем движке: сначала удержание текущего, потом ответ.
    other.value = c.copyWith(held: true);
    call.value = o!.copyWith(phase: CallPhase.active, since: DateTime.now(), route: c.route);
  }

  @override
  void rejectOther({bool busy = false}) {
    if (other.value?.phase == CallPhase.incoming) other.value = null;
  }

  @override
  void swap() {
    final c = call.value;
    final o = other.value;
    if (c == null || o == null || c.phase != CallPhase.active || o.phase != CallPhase.active) return;
    other.value = c.copyWith(held: true);
    call.value = o.copyWith(held: false, route: c.route);
  }

  @override
  void consult(String number, {String? name}) {
    final c = call.value;
    if (number.isEmpty || c == null || c.phase != CallPhase.active || other.value != null) return;
    // Как в настоящем движке: сначала удерживаем текущий, потом звоним. Сначала [other], потом [call]:
    // так первый звонок ни на миг не пропадает из обоих полей (см. CallEngine.other).
    other.value = c.copyWith(held: true);
    final id = nextCallId();
    call.value = CallInfo(
      phase: CallPhase.outgoing,
      number: number,
      name: name,
      incoming: false,
      secure: true,
      route: c.route,
      id: id,
    );
    // Отвечает через ту же паузу, что и при обычном наборе.
    _answerTimer?.cancel();
    _answerTimer = Timer(answerAfter, () {
      final now = call.value;
      if (now?.id == id && now?.phase == CallPhase.outgoing) {
        call.value = now!.copyWith(phase: CallPhase.active, since: DateTime.now());
      }
    });
  }

  @override
  void connectCalls() {
    final c = call.value;
    final o = other.value;
    if (c == null || o == null || c.phase != CallPhase.active || o.phase != CallPhase.active) return;
    if (failConnect) {
      reportFailure(CallFailure.transfer);
      return;
    }
    // Оба звонка уходят с этого телефона: собеседники теперь говорят друг с другом.
    other.value = null;
    call.value = null;
  }

  /// В какую комнату объединяли звонки последний раз — для тестов.
  String? conferenceRoom;

  @override
  void conference(String room, {String? name}) {
    final c = call.value;
    final o = other.value;
    if (c == null || o == null || c.phase != CallPhase.active || o.phase != CallPhase.active) return;
    if (failConnect) {
      reportFailure(CallFailure.transfer);
      return;
    }
    conferenceRoom = room;
    // Оба собеседника ушли в комнату, а на телефоне — один новый разговор с ней.
    other.value = null;
    call.value = CallInfo(
      id: nextCallId(),
      phase: CallPhase.active,
      number: room,
      name: name,
      incoming: false,
      secure: true,
      since: DateTime.now(),
    );
  }

  @override
  void reject() => hangUp();

  @override
  void transfer(String target) => hangUp();

  @override
  void setMuted(bool muted) => call.value = call.value?.copyWith(muted: muted);

  @override
  void setHeld(bool held) => call.value = call.value?.copyWith(held: held);

  @override
  void setSpeaker(bool on) => call.value = call.value?.copyWith(speaker: on);

  @override
  void setRoute(AudioRoute route) => call.value = call.value?.copyWith(route: route.kind);

  @override
  void sendDtmf(String tone) => sentTones.add(tone);

  /// Что набирали во время разговора (клавиши донабора и служебные коды) — для тестов.
  final sentTones = <String>[];

  @override
  void dispose() {
    _answerTimer?.cancel();
    super.dispose();
  }
}

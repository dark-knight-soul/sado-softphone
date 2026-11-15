import 'dart:async';

import '../state/account.dart';
import 'call_engine.dart';

/// Имитация звонков без АТС: «связь» есть сразу, «собеседник» отвечает через две секунды.
/// Нужна для демонстрации (сервер `demo`) и для тестов.
class DemoEngine extends CallEngine {
  DemoEngine({this.answerAfter = const Duration(seconds: 2)});

  final Duration answerAfter;
  Timer? _answerTimer;

  @override
  Future<LinkStatus> connect(Account account, String password, {bool keepTrying = false}) async {
    link.value = LinkStatus.online;
    return LinkStatus.online;
  }

  @override
  void dial(String number, {String? name}) {
    if (call.value != null || number.isEmpty) return;
    // В имитации отмечаем звонок защищённым, чтобы был виден весь экран.
    call.value = CallInfo(phase: CallPhase.outgoing, number: number, name: name, incoming: false, secure: true);
    _answerTimer = Timer(answerAfter, () {
      final c = call.value;
      if (c?.phase == CallPhase.outgoing) {
        call.value = c!.copyWith(phase: CallPhase.active, since: DateTime.now());
      }
    });
  }

  /// Показывает входящий звонок (кнопка в настройках, чтобы посмотреть экран).
  void simulateIncoming({required String number, String? name}) {
    if (call.value != null) return;
    call.value = CallInfo(phase: CallPhase.incoming, number: number, name: name, incoming: true, secure: true);
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
    call.value = null;
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
  void sendDtmf(String tone) {}

  @override
  void dispose() {
    _answerTimer?.cancel();
    super.dispose();
  }
}

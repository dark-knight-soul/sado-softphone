import '../data/push_info.dart';
import '../state/account.dart';
import 'call_engine.dart';
import 'demo_engine.dart';

/// В браузерной версии настоящих звонков нет: веб-часть sip_ua 1.1.0 не собирается с текущим
/// пакетом `web`. Браузерная версия нужна только для просмотра экранов (вход `demo`).
/// Когда выйдет исправленная sip_ua, этот файл можно будет заменить на SipEngine.
CallEngine createRealEngine() => _UnsupportedEngine();

/// Честно отказывает во входе, а не изображает связь.
class _UnsupportedEngine extends DemoEngine {
  @override
  Future<LinkStatus> connect(Account account, String password, {bool keepTrying = false, PushInfo? push}) async {
    const status = LinkStatus(LinkState.failed, LinkError.other);
    link.value = status;
    return status;
  }

  @override
  void dial(String number, {String? name}) => reportFailure(CallFailure.offline);
}

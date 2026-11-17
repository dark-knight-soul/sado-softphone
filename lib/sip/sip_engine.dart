import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:logger/logger.dart';
import 'package:sip_ua/sip_ua.dart' as sip;
// События хода перевода (ответы АТС на REFER) пакет наружу не отдаёт, а без них не узнать, соединила ли АТС
// собеседников. Версия sip_ua закреплена в pubspec.lock; при её обновлении этот импорт нужно проверить.
// ignore: implementation_imports
import 'package:sip_ua/src/event_manager/refer_events.dart' as refer;

import '../data/demo_data.dart';
import '../data/push_info.dart';
import '../state/account.dart';
import 'call_engine.dart';
import 'pidf.dart';

/// Настоящие звонки: SIP поверх WebSocket (библиотека sip_ua), звук — WebRTC.
///
/// Приложение разговаривает с АТС тем же способом, что и софтфон в браузере:
/// телефон → WebSocket → Kamailio → Asterisk.
class SipEngine extends CallEngine implements sip.SipUaHelperListener {
  SipEngine() {
    _link = _Link(this, _newHelper());
  }

  /// Сколько ждать первого ответа сервера при входе.
  static const _connectTimeout = Duration(seconds: 12);

  // Свой журнал вместо встроенного в sip_ua, по двум причинам:
  //  1) встроенный печатает каждое SIP-сообщение — оставляем только предупреждения;
  //  2) встроенный при первом обращении разбирает стек вызовов и падает на путях Windows
  //     («C:/…» — двоеточие после буквы диска), из-за чего подключение срывалось.
  // В собранном приложении журнал молчит вовсе (так устроен пакет logger).
  // Для разбора неполадок на телефоне: сборка с --dart-define=SADO_SIP_LOG=true печатает подробный
  // журнал SIP в logcat и в собранном приложении. В обычных сборках этого нет.
  static const _verbose = bool.fromEnvironment('SADO_SIP_LOG');
  static sip.SIPUAHelper _newHelper() => sip.SIPUAHelper(
    customLogger: Logger(
      level: _verbose ? Level.debug : Level.warning,
      filter: _verbose ? ProductionFilter() : null,
      printer: SimplePrinter(colors: false),
    ),
  );

  /// Нынешнее подключение к АТС: свой экземпляр sip_ua и свой канал событий. На каждое новое подключение
  /// заводится новое — иначе запоздавшее событие остановленного («соединение закрыто») приходило бы
  /// в обработчики нового и срывало его.
  late _Link _link;
  sip.SIPUAHelper get _helper => _link.helper;
  Account? _account;

  /// Какой звонок мы сейчас сами снимаем с удержания (id звонка sip_ua; см. обработку UNHOLD).
  String? _unholding;
  bool _keepTrying = false;
  bool _started = false;

  /// Сколько начатых вызовов человек отменил раньше, чем sip_ua успела их создать (см. CALL_INITIATION).
  int _cancelledDials = 0;

  /// Сколько ждать от АТС итога перевода с консультацией. Не дождались — считаем, что не вышло, звонки не трогаем.
  static const _connectCallsTimeout = Duration(seconds: 15);

  /// Идёт перевод с консультацией (REFER отправлен, ждём итога от АТС); таймер — предел ожидания.
  Timer? _connectingTimer;
  bool get _connecting => _connectingTimer != null;

  /// Номера, за статусами которых просили следить, и те из них, на которые подписка уже отправлена.
  Set<String> _watched = const {};
  final Set<String> _subscribed = {};

  /// Больше стольких подписок не держим: каждая — это отдельный обмен с АТС раз в четверть часа
  /// и уведомление при каждом звонке коллеги.
  static const _presenceLimit = 60;

  /// Подписки отправляем по одной с такой паузой: пачку запросов разом сервер перед АТС (например, Kamailio
  /// с защитой от наплыва запросов) может принять за атаку и заблокировать адрес — вместе со звонками.
  @visibleForTesting
  static const subscribeGap = Duration(milliseconds: 500);
  Timer? _subscribeTimer;

  /// Повтор регистрации после сбоя: sip_ua сама её не повторяет, пока соединение с сервером цело.
  Timer? _retryTimer;
  Duration _retryDelay = _retryMin;
  static const _retryMin = Duration(seconds: 5);
  static const _retryMax = Duration(seconds: 60);
  Completer<LinkStatus>? _firstResult;
  Timer? _connectTimer;

  /// Текущий звонок (его показывает [call]).
  sip.Call? _current;

  /// Второй звонок: ожидает ответа или на удержании (его показывает [other]).
  sip.Call? _other;

  /// Звук собеседника каждого звонка (id звонка → поток) — чтобы в браузере переключать звук при смене звонков.
  final Map<String?, rtc.MediaStream> _remoteStreams = {};

  // В браузере звук собеседника сам не заиграет — его нужно отдать «проигрывателю».
  // На телефоне WebRTC играет звук сам, проигрыватель там не создаём.
  rtc.RTCVideoRenderer? _webAudio;

  @override
  Future<LinkStatus> connect(Account account, String password, {bool keepTrying = false, PushInfo? push}) {
    _account = account;
    _keepTrying = keepTrying;
    // Прежнее подключение ещё не дало итога — отвечаем тем, кто его ждал, что оно отменено:
    // иначе их ожидание не закончилось бы никогда.
    _abandonFirstResult();
    _firstResult = Completer<LinkStatus>();
    link.value = LinkStatus.connecting;

    final settings = sip.UaSettings()
      ..transportType = sip.TransportType.WS
      ..webSocketUrl = account.wsUrl
      ..uri = 'sip:${account.number}@${account.domain}'
      ..authorizationUser = account.number
      ..password = password
      ..displayName = account.number
      ..userAgent = 'Sado-Mobile/1.0'
      ..register = true
      ..register_expires = 300
      // Цифры донабора идут в звуковом потоке — так их понимает любой Asterisk без настройки.
      ..dtmfMode = sip.DtmfMode.RFC2833
      // Посторонние STUN-серверы (по умолчанию там стоит сервер Google) не используем:
      // АТС доступна напрямую, а лишний запрос наружу — это задержка и утечка адреса.
      ..iceServers = <Map<String, String>>[];
    settings.webSocketSettings.userAgent = 'Sado-Mobile/1.0';
    if (push != null) {
      // Режим «будить по звонку»: сообщаем АТС, куда слать push (RFC 8599). Параметры попадают в адрес
      // Contact регистрации; при снятии регистрации АТС их забывает.
      settings.registerParams.extraContactUriParams = <String, dynamic>{
        'pn-provider': push.provider,
        'pn-param': push.project,
        'pn-prid': push.token,
      };
    }

    _connectTimer?.cancel();
    _connectTimer = Timer(_connectTimeout, () => _settle(const LinkStatus(LinkState.failed, LinkError.network)));

    // Экземпляр sip_ua уже работал (или был остановлен) — подключаемся новым, старый окончательно глушим.
    if (_link.used) {
      final old = _link;
      old.live = false;
      if (_started) old.helper.stop();
      _link = _Link(this, _newHelper());
    }
    _link.used = true;
    _link.live = true;
    _started = true;
    unawaited(
      _helper.start(settings).catchError((Object e) {
        _settle(const LinkStatus(LinkState.failed, LinkError.other));
      }),
    );
    return _firstResult!.future;
  }

  /// Записывает итог подключения. Первый итог возвращается из [connect].
  void _settle(LinkStatus status) {
    if (link.value != status) link.value = status;
    final first = _firstResult;
    if (first != null && !first.isCompleted) {
      _connectTimer?.cancel();
      first.complete(status);
      // При входе с экрана входа неудача окончательна: не оставляем sip_ua переподключаться в фоне.
      if (!status.isOnline && !_keepTrying) _stop();
    }
  }

  /// Сколько ждать от АТС подтверждения, что регистрация снята ([sleep]).
  static const _unregisterTimeout = Duration(seconds: 5);

  /// Ждёт подтверждения снятия регистрации; завершается и при обрыве соединения.
  Completer<void>? _unregistered;

  /// Отвечает «не на связи» тому, кто ещё ждёт первого итога [connect], и снимает его таймер.
  void _abandonFirstResult() {
    _connectTimer?.cancel();
    final first = _firstResult;
    if (first != null && !first.isCompleted) first.complete(LinkStatus.offline);
  }

  @override
  Future<void> sleep() async {
    if (_current != null || _other != null) return;
    final registered = _started && link.value.isOnline;
    _keepTrying = false;
    _abandonFirstResult();
    final done = Completer<void>();
    _unregistered = done;
    // Остановка sip_ua сама снимает регистрацию на АТС и закрывает соединение.
    _stop();
    _subscribed.clear();
    if (presence.value.isNotEmpty) presence.value = const {};
    link.value = LinkStatus.offline;
    // Дожидаемся ответа АТС: вызвавший после этого может остановить фоновую службу, и если запрос не успеет
    // уйти, АТС будет считать телефон на связи и слать звонки в закрытое соединение, а не будить его.
    if (registered) await done.future.timeout(_unregisterTimeout, onTimeout: () {});
    if (identical(_unregistered, done)) _unregistered = null;
  }

  void _confirmUnregistered() {
    final waiting = _unregistered;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  void _stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _subscribeTimer?.cancel();
    _subscribeTimer = null;
    if (!_started) return;
    _started = false;
    // С этого момента события этого подключения движку не нужны — кроме подтверждения, что регистрация снята.
    _link.live = false;
    _helper.stop();
  }

  // ---- События sip_ua ----

  @override
  void transportStateChanged(sip.TransportState state) {
    switch (state.state) {
      case sip.TransportStateEnum.DISCONNECTED:
        final first = _firstResult;
        if (first != null && !first.isCompleted && !_keepTrying) {
          _settle(const LinkStatus(LinkState.failed, LinkError.network));
        } else if (_started) {
          // Связь пропала уже после подключения — sip_ua переподключается сама.
          link.value = LinkStatus.connecting;
        }
        // Подписки на статусы с обрывом связи пропадают; после новой регистрации оформим их заново.
        _subscribeTimer?.cancel();
        _subscribeTimer = null;
        _subscribed.clear();
        if (presence.value.isNotEmpty) presence.value = const {};
      case sip.TransportStateEnum.CONNECTING:
        if (!link.value.isOnline) link.value = LinkStatus.connecting;
      case sip.TransportStateEnum.CONNECTED:
      case sip.TransportStateEnum.NONE:
        break;
    }
  }

  @override
  void registrationStateChanged(sip.RegistrationState state) {
    switch (state.state) {
      case sip.RegistrationStateEnum.REGISTERED:
        _retryTimer?.cancel();
        _retryDelay = _retryMin;
        _settle(LinkStatus.online);
        _subscribeMissing();
      case sip.RegistrationStateEnum.REGISTRATION_FAILED:
        final code = state.cause?.status_code;
        final auth = code == 401 || code == 403 || code == 404;
        _settle(LinkStatus(LinkState.failed, auth ? LinkError.auth : LinkError.network));
        // С неверным паролем повторять бессмысленно, а сервер за перебор может заблокировать адрес.
        if (auth) {
          _stop();
        } else if (_started) {
          // Сбой не из-за пароля (сервер перезапускается, ответ не дошёл): пробуем снова, с растущей паузой.
          // Без этого номер оставался бы «не на связи», пока приложение не перезапустят.
          _retryTimer?.cancel();
          _retryTimer = Timer(_retryDelay, () {
            if (_started) _helper.register();
          });
          final next = _retryDelay * 2;
          _retryDelay = next > _retryMax ? _retryMax : next;
        }
      case sip.RegistrationStateEnum.UNREGISTERED:
        if (_started) link.value = LinkStatus.connecting;
      case sip.RegistrationStateEnum.NONE:
      case null:
        break;
    }
  }

  @override
  void callStateChanged(sip.Call sipCall, sip.CallState state) {
    switch (state.state) {
      case sip.CallStateEnum.CALL_INITIATION:
        if (_isCurrent(sipCall) || _isOther(sipCall)) return;
        final incoming = sipCall.direction == sip.Direction.incoming;
        // Эта проверка стоит первой: отменённый вызов нужно снять и «списать» со счёта, даже если за это время
        // успел прийти другой звонок, — иначе следующий настоящий вызов был бы отменён вместо него.
        if (!incoming && _cancelledDials > 0) {
          // Человек нажал «Завершить» раньше, чем библиотека успела создать вызов. Отменяем его здесь,
          // иначе у собеседника зазвонил бы телефон, а у нас не было бы ни экрана, ни уведомления.
          _cancelledDials--;
          try {
            _end(sipCall);
          } catch (_) {
            // Вызов мог ещё не дойти до состояния, из которого его можно отменить, — тогда он завершится сам.
          }
          return;
        }
        if (_current != null || (incoming && call.value != null)) {
          // Второй входящий ждёт ответа, только пока первый звонок уже соединён. Третий звонок, второй во время
          // вызова или звонка, на который ещё не ответили, — «занято», как раньше.
          if (incoming && _other == null && _current != null && call.value?.phase == CallPhase.active) {
            _other = sipCall;
            other.value = _incomingInfo(sipCall);
          } else {
            _end(sipCall, <String, dynamic>{'status_code': 486});
          }
          return;
        }
        _current = sipCall;
        if (incoming) call.value = _incomingInfo(sipCall);
      case sip.CallStateEnum.ACCEPTED:
      case sip.CallStateEnum.CONFIRMED:
        if (!_isCurrent(sipCall)) return;
        final c = call.value;
        // since == null у активного — это второй звонок, на который мы только что ответили (см. acceptOther):
        // таймер пускаем, когда разговор действительно соединился.
        if (c != null && (c.phase != CallPhase.active || c.since == null)) {
          // Второй звонок — тот, на который ответили при удержанном первом, или вызов «Сначала поговорить»
          // (первый в это время на удержании): звук для них уже настроен первым разговором.
          final second = c.phase == CallPhase.active || other.value != null;
          call.value = c.copyWith(phase: CallPhase.active, since: DateTime.now());
          // Звук пошёл — ещё раз говорим телефону, куда его выводить (к этому моменту его «звуковая часть»
          // точно запущена и послушается). У второго звонка звук уже мог идти в гарнитуру — повторяем
          // выбранное устройство, а не «громкая связь вкл/выкл», которое увело бы звук из гарнитуры.
          unawaited(second ? _selectKind(c.route) : _setSpeakerphone(c.speaker));
          unawaited(_refreshRoutes());
        }
      case sip.CallStateEnum.STREAM:
        final stream = state.stream;
        if (state.originator == sip.Originator.remote && stream != null) {
          _remoteStreams[sipCall.id] = stream;
          if (_isCurrent(sipCall)) unawaited(_playOnWeb(stream));
        }
      case sip.CallStateEnum.HOLD:
        final slot = _slotOf(sipCall);
        if (slot != null && state.originator == sip.Originator.local) {
          slot.value = slot.value?.copyWith(held: true);
        }
      case sip.CallStateEnum.UNHOLD:
        // В sip_ua 1.1.0 у события «удержание снято» не заполнено, кто его снял (ошибка в библиотеке:
        // конструктор EventCallUnhold в event_manager/call_events.dart не сохраняет originator),
        // поэтому сами помним, какой звонок снимали мы. Иначе кнопка «Удержать» навсегда оставалась нажатой.
        final slot = _slotOf(sipCall);
        if (slot != null && (_unholding == sipCall.id || state.originator == sip.Originator.local)) {
          slot.value = slot.value?.copyWith(held: false);
        }
      case sip.CallStateEnum.MUTED:
      case sip.CallStateEnum.UNMUTED:
        final slot = _slotOf(sipCall);
        if (slot != null) {
          slot.value = slot.value?.copyWith(muted: state.state == sip.CallStateEnum.MUTED);
        }
      case sip.CallStateEnum.FAILED:
        if (_isOther(sipCall)) {
          _clearOther();
          return;
        }
        if (!_isCurrent(sipCall)) return;
        final failure = _failureOf(state);
        _clearCall();
        if (failure != null) reportFailure(failure);
      case sip.CallStateEnum.ENDED:
        if (_isOther(sipCall)) {
          _clearOther();
        } else if (_isCurrent(sipCall)) {
          _clearCall();
        }
      case sip.CallStateEnum.NONE:
      case sip.CallStateEnum.CONNECTING:
      case sip.CallStateEnum.PROGRESS:
      case sip.CallStateEnum.REFER:
        break;
    }
  }

  bool _isCurrent(sip.Call sipCall) => _current != null && _current!.id == sipCall.id;

  bool _isOther(sip.Call sipCall) => _other != null && _other!.id == sipCall.id;

  /// Поле, в котором движок показывает этот звонок; null — звонок не наш (уже завершён или отклонён «занято»).
  ValueNotifier<CallInfo?>? _slotOf(sip.Call sipCall) => _isCurrent(sipCall)
      ? call
      : _isOther(sipCall)
      ? other
      : null;

  /// Входящий звонок, каким его видит приложение.
  CallInfo _incomingInfo(sip.Call sipCall) {
    // Звонящий без номера приходит как «anonymous» — это не имя и не номер, показываем «Неизвестный номер».
    final raw = sipCall.remote_identity ?? '';
    final number = raw.toLowerCase() == 'anonymous' ? '' : raw;
    final rawName = sipCall.remote_display_name ?? '';
    final shown = rawName.toLowerCase() == 'anonymous' ? '' : rawName;
    return CallInfo(
      phase: CallPhase.incoming,
      number: number,
      name: shown.isEmpty || shown == number ? null : shown,
      incoming: true,
      secure: _account?.secureTransport ?? false,
      id: nextCallId(),
    );
  }

  /// Ставит звонок на удержание. false — sip_ua отказалась (разговор ещё не установлен или идёт другой
  /// обмен re-INVITE). RTCSession.hold() сразу, ещё до ответа АТС, выключает наш микрофон в этом звонке
  /// и присылает событие HOLD; обёртка sip.Call.hold() этот результат теряет, поэтому зовём сессию напрямую.
  bool _hold(sip.Call sipCall) {
    try {
      return sipCall.session.hold();
    } catch (_) {
      return false;
    }
  }

  /// Снимает звонок с удержания. Событие UNHOLD приходит прямо во время вызова unhold(), поэтому отметку ставим до него.
  bool _resume(sip.Call sipCall) {
    _unholding = sipCall.id;
    try {
      return sipCall.session.unhold();
    } catch (_) {
      return false;
    } finally {
      _unholding = null;
    }
  }

  /// Переводит причину сбоя из sip_ua в понятную человеку. null — сбоя «для показа» нет
  /// (например, мы сами отменили вызов или собеседник не дождался ответа).
  CallFailure? _failureOf(sip.CallState state) {
    final wasIncoming = call.value?.incoming ?? false;
    final code = state.cause?.status_code;
    final cause = state.cause?.cause;
    if (cause == 'Canceled') return null;
    if (state.originator == sip.Originator.local && cause != 'User Denied Media Access') return null;
    if (wasIncoming && cause != 'User Denied Media Access') return null;
    if (cause == 'User Denied Media Access') return CallFailure.micDenied;
    if (cause == 'Busy' || code == 486 || code == 600) return CallFailure.busy;
    if (cause == 'Rejected' || code == 603 || code == 403) return CallFailure.rejected;
    if (cause == 'No Answer' || code == 408) return CallFailure.noAnswer;
    if (cause == 'Unavailable' || cause == 'Not Found' || code == 480 || code == 404) return CallFailure.unavailable;
    if (cause == 'Connection Error' || cause == 'Request Timeout') return CallFailure.offline;
    return CallFailure.other;
  }

  void _clearCall() {
    _remoteStreams.remove(_current?.id);
    final next = _other;
    final nextInfo = other.value;
    if (next != null && nextInfo != null) {
      // Текущий кончился, но есть второй — он занимает место текущего, экран и уведомление остаются.
      // Звук оставляем там, куда его вывел человек. Сначала [call], потом [other] — см. CallEngine.other.
      // Ожидавший ответа второй звонок дальше звонит как обычный входящий.
      final route = call.value?.route ?? nextInfo.route;
      _current = next;
      _other = null;
      call.value = nextInfo.copyWith(route: route);
      other.value = null;
      if (nextInfo.phase == CallPhase.active) {
        // Удержанный снимаем с удержания. Если sip_ua сейчас не может (идёт другой обмен), звонок
        // остаётся на удержании — человек снимет его кнопкой «Удержать».
        // Пока АТС переводит этот звонок (connectCalls), не трогаем его: снятие с удержания помешало бы переводу.
        if (!_connecting) _resume(next);
        final player = _webAudio;
        if (player != null) player.srcObject = _remoteStreams[next.id];
      }
      return;
    }
    final hadSpeaker = call.value?.speaker ?? false;
    _current = null;
    call.value = null;
    _stopWatchingRoutes();
    if (hadSpeaker) unawaited(_setSpeakerphone(false));
    final player = _webAudio;
    if (player != null) player.srcObject = null;
  }

  /// Второй звонок закончился (ожидающий не дождался ответа или удержанный положил трубку); текущий не трогаем.
  void _clearOther() {
    _remoteStreams.remove(_other?.id);
    _other = null;
    other.value = null;
  }

  Future<void> _playOnWeb(rtc.MediaStream? stream) async {
    if (!kIsWeb || stream == null) return;
    var player = _webAudio;
    if (player == null) {
      player = rtc.RTCVideoRenderer();
      await player.initialize();
      _webAudio = player;
    }
    player.srcObject = stream;
  }

  bool _audioPrepared = false;

  /// Готовит звук к разговору. Без этого библиотека звука ведёт себя как проигрыватель музыки:
  /// включает громкую связь сама и регулирует «громкость музыки», а не громкость разговора.
  Future<void> _prepareAudio() async {
    if (kIsWeb) return;
    try {
      if (!_audioPrepared && defaultTargetPlatform == TargetPlatform.android) {
        _audioPrepared = true;
        await rtc.Helper.setAndroidAudioConfiguration(rtc.AndroidAudioConfiguration.communication);
      }
    } catch (_) {
      // Старое устройство без такой настройки — остаётся выбор динамика ниже.
    }
    // Разговор всегда начинается «в ухо» (или в гарнитуру, если она подключена); громкую связь включает человек.
    await _setSpeakerphone(false);
    _watchRoutes();
    await _refreshRoutes();
  }

  // ---- Устройства вывода звука ----

  bool _watchingRoutes = false;

  /// Следим за подключением и отключением гарнитур, пока идёт звонок.
  void _watchRoutes() {
    if (kIsWeb || _watchingRoutes) return;
    try {
      rtc.navigator.mediaDevices.ondevicechange = (_) => unawaited(_refreshRoutes());
      _watchingRoutes = true;
    } catch (_) {
      // Платформа не сообщает о смене устройств — список обновится при следующем событии звонка.
    }
  }

  void _stopWatchingRoutes() {
    routes.value = const [];
    if (!_watchingRoutes) return;
    _watchingRoutes = false;
    try {
      rtc.navigator.mediaDevices.ondevicechange = null;
    } catch (_) {
      // Уже отписаны вместе с платформой.
    }
  }

  AudioKind _bestKind(Set<AudioKind> kinds) => kinds.contains(AudioKind.bluetooth)
      ? AudioKind.bluetooth
      : kinds.contains(AudioKind.wired)
      ? AudioKind.wired
      : kinds.contains(AudioKind.earpiece)
      ? AudioKind.earpiece
      : AudioKind.speaker;

  /// Читает у телефона список устройств звука и, если выбранное пропало (или появилась гарнитура,
  /// пока звук шёл в трубку), переводит звук на подходящее.
  Future<void> _refreshRoutes() async {
    if (kIsWeb) return;
    try {
      final devices = await rtc.Helper.audiooutputs;
      if (call.value == null) return; // звонок успел закончиться, пока ждали ответ телефона
      final found = <AudioRoute>[];
      for (final d in devices) {
        // Код устройства на Android — тип из AudioDeviceKind.java: bluetooth, wired-headset, speaker, earpiece.
        final kind = switch (d.deviceId) {
          'earpiece' => AudioKind.earpiece,
          'speaker' => AudioKind.speaker,
          'bluetooth' => AudioKind.bluetooth,
          'wired-headset' => AudioKind.wired,
          _ => null,
        };
        if (kind == null || found.any((r) => r.kind == kind)) continue;
        found.add(AudioRoute(kind, kind == AudioKind.bluetooth && d.label.isNotEmpty ? d.label : null));
      }
      if (found.isEmpty) return;
      found.sort((a, b) => a.kind.index.compareTo(b.kind.index));
      // Что было доступно до этого обновления — чтобы отличить «гарнитуру только что подключили»
      // от «гарнитура давно подключена, но человек сам выбрал трубку».
      final before = routes.value.map((r) => r.kind).toSet();
      routes.value = found;

      final current = call.value!.route;
      final kinds = found.map((r) => r.kind).toSet();
      final best = _bestKind(kinds);
      final headsetAppeared =
          current == AudioKind.earpiece &&
          (best == AudioKind.bluetooth || best == AudioKind.wired) &&
          !before.contains(best);
      // Выбранного устройства больше нет — или гарнитуру подключили, пока звук шёл в трубку: уходим в лучшее из доступных.
      if (!kinds.contains(current) || headsetAppeared) await _selectKind(best);
    } catch (_) {
      // Сбой в списке устройств не должен ломать разговор: останется переключатель «динамик».
    }
  }

  /// Переключает звук на устройство и запоминает выбор в состоянии звонка.
  Future<void> _selectKind(AudioKind kind) async {
    if (call.value == null) return;
    call.value = call.value!.copyWith(route: kind);
    if (kIsWeb) return;
    final id = switch (kind) {
      AudioKind.earpiece => 'earpiece',
      AudioKind.speaker => 'speaker',
      AudioKind.bluetooth => 'bluetooth',
      AudioKind.wired => 'wired-headset',
    };
    try {
      await rtc.Helper.selectAudioOutput(id);
    } catch (_) {
      // Крайний случай для трубки и динамика: старый способ «громкая связь вкл/выкл».
      if (kind == AudioKind.speaker || kind == AudioKind.earpiece) await _setSpeakerphone(kind == AudioKind.speaker);
    }
  }

  Future<void> _setSpeakerphone(bool on) async {
    if (kIsWeb) return; // в браузере звук идёт туда, куда выбрал сам браузер
    try {
      await rtc.Helper.setSpeakerphoneOn(on);
    } catch (_) {
      // На устройстве без громкой связи переключать нечего.
    }
  }

  // ---- Команды ----

  /// Запускает вызов в sip_ua. Сам звонок появляется позже, в CALL_INITIATION. Общий путь для [dial] и [consult]:
  /// если вызов не начался, текущий звонок убирается (при консультации на его место возвращается удержанный).
  void _startCall(String target) {
    unawaited(
      _helper
          .call(target, voiceOnly: true)
          .then((started) {
            // Вызов не начался вовсе — отменять будет нечего.
            if (!started && _cancelledDials > 0) _cancelledDials--;
            if (!started && _current == null) {
              _clearCall();
              reportFailure(CallFailure.offline);
            }
          })
          .catchError((Object e) {
            if (_current == null) {
              _clearCall();
              reportFailure(CallFailure.other);
            }
          }),
    );
  }

  @override
  void dial(String number, {String? name}) {
    final target = dialTarget(number);
    if (call.value != null || target.isEmpty) return;
    if (!link.value.isOnline) {
      reportFailure(CallFailure.offline);
      return;
    }
    // Экран вызова показываем сразу, не дожидаясь ответа сети.
    call.value = CallInfo(
      phase: CallPhase.outgoing,
      number: number,
      name: name,
      incoming: false,
      secure: _account?.secureTransport ?? false,
    );
    unawaited(_prepareAudio());
    _startCall(target);
  }

  @override
  void accept() {
    if (call.value?.phase != CallPhase.incoming) return;
    unawaited(_prepareAudio());
    _current?.answer(_helper.buildCallOptions(true));
  }

  @override
  void hangUp() {
    final c = call.value;
    final current = _current;
    if (current == null) {
      // Сеть ещё не успела создать вызов — убираем экран и помечаем, что вызов нужно отменить, когда он появится.
      if (c != null) {
        if (c.phase == CallPhase.outgoing) _cancelledDials++;
        _clearCall();
      }
      return;
    }
    // Неотвеченный входящий отклоняем явным «отклонено», а не «недоступен».
    final declining = c?.phase == CallPhase.incoming;
    _end(current, declining ? <String, dynamic>{'status_code': 603} : null);
  }

  /// Завершает звонок sip_ua (или отклоняет его — тогда в [options] код ответа).
  ///
  /// Перед отправкой «конец связи» библиотека останавливает звуковые потоки, и этот шаг может сорваться
  /// или молча прервать завершение. Тогда завершаем сам сеанс напрямую — иначе человек остался бы
  /// в разговоре, который нельзя положить.
  void _end(sip.Call? sipCall, [Map<String, dynamic>? options]) {
    if (sipCall == null) return;
    try {
      sipCall.hangup(options);
      if (sipCall.session.isEnded()) return;
    } catch (_) {
      // Сорвалась остановка потоков — завершаем сеанс ниже.
    }
    try {
      sipCall.session.terminate(options);
    } catch (_) {
      // Сеанс уже завершён или завершается.
    }
  }

  @override
  void reject() {
    if (call.value?.phase == CallPhase.incoming) _end(_current, <String, dynamic>{'status_code': 486});
  }

  @override
  void transfer(String target) {
    final to = dialTarget(target);
    if (to.isEmpty || call.value?.phase != CallPhase.active) return;
    // АТС сама соединит собеседника с новым номером; когда она подтвердит перевод, sip_ua завершит наш звонок.
    _current?.refer(to);
  }

  @override
  void setMuted(bool muted) {
    final current = _current;
    if (current == null) return;
    muted ? current.mute(true, false) : current.unmute(true, false);
  }

  @override
  void setHeld(bool held) {
    final current = _current;
    if (current == null || call.value?.phase != CallPhase.active) return;
    if (held) {
      current.hold();
    } else {
      // Событие приходит прямо во время вызова unhold(), поэтому отметку ставим до него.
      _unholding = current.id;
      try {
        current.unhold();
      } finally {
        _unholding = null;
      }
    }
  }

  @override
  void setSpeaker(bool on) {
    if (call.value == null) return;
    // Выключая громкую связь, возвращаем звук в гарнитуру, если она есть, иначе в трубку.
    final off = _bestKind(routes.value.map((r) => r.kind).toSet()..remove(AudioKind.speaker));
    if (on || off == AudioKind.earpiece || off == AudioKind.speaker) {
      // Прежний путь без списка устройств: так работает и там, где телефон список не назвал.
      call.value = call.value!.copyWith(speaker: on);
      unawaited(_setSpeakerphone(on));
    } else {
      unawaited(_selectKind(off));
    }
  }

  @override
  void setRoute(AudioRoute route) {
    if (call.value == null) return;
    unawaited(_selectKind(route.kind));
  }

  @override
  void sendDtmf(String tone) {
    if (call.value?.phase == CallPhase.active) _current?.sendDTMF(tone);
  }

  @override
  void acceptOther() {
    final current = _current;
    final waiting = _other;
    final c = call.value;
    final w = other.value;
    if (current == null || waiting == null || c == null || w == null) return;
    if (c.phase != CallPhase.active || w.phase != CallPhase.incoming) return;
    // Сначала удерживаем текущий и только потом отвечаем: если удержать не вышло, не отвечаем вовсе —
    // иначе оба разговора шли бы вживую одновременно.
    if (!c.held && !_hold(current)) return;
    final held = call.value ?? c.copyWith(held: true);
    _current = waiting;
    _other = current;
    // Ответ уходит сразу; таймер пойдёт, когда звонок соединится (since == null, см. ACCEPTED).
    // Звук — туда же, где шёл первый разговор: аудио уже настроено, его не сбрасываем (без _prepareAudio).
    // Сначала [call], потом [other] — см. CallEngine.other.
    call.value = w.copyWith(phase: CallPhase.active, route: held.route);
    other.value = held;
    waiting.answer(_helper.buildCallOptions(true));
  }

  @override
  void rejectOther({bool busy = false}) {
    if (other.value?.phase != CallPhase.incoming) return;
    // Те же ответы, что и у обычного входящего: «Отклонить» — 603, «Не беспокоить» — 486 (см. hangUp и reject).
    _end(_other, <String, dynamic>{'status_code': busy ? 486 : 603});
  }

  @override
  void swap() {
    final current = _current;
    final held = _other;
    final c = call.value;
    final h = other.value;
    if (current == null || held == null || c == null || h == null) return;
    if (c.phase != CallPhase.active || h.phase != CallPhase.active) return;
    // Сначала удерживаем текущий, потом снимаем с удержания второй: сбой на любом шаге оставит
    // оба звонка на удержании, но никогда — оба вживую.
    if (!c.held && !_hold(current)) return;
    final nowHeld = call.value ?? c.copyWith(held: true);
    _current = held;
    _other = current;
    call.value = h.copyWith(route: nowHeld.route);
    other.value = nowHeld;
    _resume(held);
    final player = _webAudio;
    if (player != null) player.srcObject = _remoteStreams[held.id];
  }

  @override
  void consult(String number, {String? name}) {
    final target = dialTarget(number);
    final current = _current;
    final c = call.value;
    if (target.isEmpty || current == null || c == null || c.phase != CallPhase.active) return;
    // Звонков не больше двух: консультация — только при одном звонке.
    if (_other != null || other.value != null || _connecting) return;
    if (!link.value.isOnline) {
      reportFailure(CallFailure.offline);
      return;
    }
    // Сначала удерживаем текущий (как в acceptOther): не вышло — не звоним вовсе, иначе первый собеседник
    // слышал бы наш разговор со вторым.
    if (!c.held && !_hold(current)) return;
    final held = call.value ?? c.copyWith(held: true);
    // Первый звонок становится вторым (удержанным), место текущего свободно до CALL_INITIATION: там новая
    // исходящая сессия займёт _current (ветка «_current == null»), а входящий в это время получит «занято».
    // Если человек завершит вызов раньше, hangUp увидит _current == null, пометит отмену (_cancelledDials)
    // и вернёт удержанный на место текущего (_clearCall).
    _other = current;
    _current = null;
    // Сначала [other], потом [call] — первый звонок ни на миг не пропадает из обоих полей (см. CallEngine.other).
    other.value = held;
    call.value = CallInfo(
      phase: CallPhase.outgoing,
      number: number,
      name: name,
      incoming: false,
      secure: _account?.secureTransport ?? false,
      // Звук — туда же, где шёл первый разговор: аудио уже настроено, его не сбрасываем (без _prepareAudio).
      route: held.route,
      id: nextCallId(),
    );
    _startCall(target);
  }

  @override
  void connectCalls() {
    final current = _current;
    final held = _other;
    final c = call.value;
    final h = other.value;
    if (_connecting || current == null || held == null || c == null || h == null) return;
    // Оба звонка должны быть соединены: вызов «Сначала поговорить», на который ещё не ответили, соединять нельзя.
    if (c.phase != CallPhase.active || c.since == null || h.phase != CallPhase.active) return;
    // Перевод с консультацией (RFC 5589): REFER уходит по удержанному звонку, а в Refer-To — адрес текущего
    // собеседника с заголовком Replaces, указывающим на наш разговор с ним. АТС соединяет удержанного с текущим
    // вместо нас. Заголовок Replaces собирает сама sip_ua (refer_subscriber.dart, sendRefer).
    final replaces = _ReplacesOf.from(current.session);
    final to = current.session.remote_identity?.uri?.toString();
    if (replaces == null || to == null) {
      reportFailure(CallFailure.transfer);
      return;
    }
    // Тип подписчика (ReferSubscriber) выводится из refer() — так его не нужно импортировать из недр пакета.
    final subscriber = (() {
      try {
        return held.session.refer(to, <String, dynamic>{'replaces': replaces});
      } catch (_) {
        // Адрес не разобрался (rtc_session.dart, refer(): normalizeTarget).
        return null;
      }
    })();
    // null — сессия не в том состоянии, чтобы отправить REFER (rtc_session.dart, refer()).
    if (subscriber == null) {
      reportFailure(CallFailure.transfer);
      return;
    }
    var settled = false;
    void finish(bool ok) {
      if (settled) return;
      settled = true;
      _connectingTimer?.cancel();
      _connectingTimer = null;
      if (!ok) {
        // Звонки оставляем как были: человек продолжает говорить с текущим, первый — на удержании.
        // Если пока ждали, текущий кончился и удержанный занял его место, — снимаем его с удержания сейчас.
        final now = _current;
        if (now != null && identical(now, held) && _other == null && (call.value?.held ?? false)) _resume(now);
        reportFailure(CallFailure.transfer);
        return;
      }
      // АТС соединила собеседников: убираем оба звонка с экрана (сначала удержанный, потом текущий — так
      // текущий не «оживит» удержанный при завершении) и кладём трубку на обоих. История пишется как обычно.
      for (final leg in [held, current]) {
        if (_isOther(leg)) _clearOther();
        if (_isCurrent(leg)) _clearCall();
      }
      for (final leg in [held, current]) {
        // АТС могла уже сама завершить звонок — тогда класть трубку не на чем. Проверяем заранее: terminate()
        // в sip_ua асинхронная, и её ошибку «уже завершён» try/catch здесь не поймал бы.
        if (leg.session.isEnded()) continue;
        try {
          _end(leg);
        } catch (_) {
          // Сбой при остановке звука не должен мешать завершению второго звонка.
        }
      }
    }

    // Итог приходит в NOTIFY с кодом ответа новой стороны (refer_subscriber.dart, receiveNotify): 2xx — соединила,
    // 3xx–6xx — нет. Отказ на сам REFER (например, 403 или 501) — тоже «нет».
    _connectingTimer = Timer(_connectCallsTimeout, () => finish(false));
    subscriber.on(refer.EventReferAccepted(), (refer.EventReferAccepted _) => finish(true));
    subscriber.on(refer.EventReferFailed(), (refer.EventReferFailed _) => finish(false));
    subscriber.on(refer.EventReferRequestFailed(), (refer.EventReferRequestFailed _) => finish(false));
  }

  // ---- Остальные события sip_ua нам не нужны ----

  @override
  void onNewMessage(sip.SIPMessageRequest msg) {}

  // ---- Статусы номеров ----

  @override
  void watchPresence(Set<String> numbers) {
    _watched = numbers.where(isExtensionLike).take(_presenceLimit).toSet();
    final kept = {
      for (final e in presence.value.entries)
        if (_watched.contains(e.key)) e.key: e.value,
    };
    if (kept.length != presence.value.length) presence.value = kept;
    _subscribeMissing();
  }

  /// Отправляет подписки на номера, за которыми следим, но ещё не подписаны. Нужна регистрация на АТС.
  ///
  /// Отписаться от одного номера sip_ua не даёт (подписки снимаются все разом при отключении), поэтому
  /// уведомления о номерах, за которыми следить перестали, просто пропускаем. Номер, на который АТС
  /// подписку не приняла (у неё нет его статуса), до переподключения больше не спрашиваем.
  void _subscribeMissing() {
    // Очередь уже идёт — она сама дойдёт до новых номеров.
    if (_subscribeTimer == null) _subscribeNext();
  }

  /// Отправляет одну подписку и назначает следующую через [subscribeGap].
  void _subscribeNext() {
    _subscribeTimer = null;
    final account = _account;
    if (account == null || !_started || !link.value.isOnline) return;
    String? number;
    for (final candidate in _watched) {
      if (!_subscribed.contains(candidate)) {
        number = candidate;
        break;
      }
    }
    if (number == null) return;
    // Отмечаем сразу и не снимаем отметку при сбое: иначе очередь спрашивала бы этот номер без конца.
    _subscribed.add(number);
    try {
      _helper.subscribe('sip:$number@${account.domain}', 'presence', 'application/pidf+xml');
    } catch (_) {
      // Подписку отправить не удалось — попробуем после следующего подключения.
    }
    _subscribeTimer = Timer(subscribeGap, _subscribeNext);
  }

  @override
  void onNewNotify(sip.Notify ntf) {
    final request = ntf.request;
    if (request == null) return;
    final event = '${request.getHeader('Event') ?? ''}'.toLowerCase();
    if (!event.startsWith('presence')) return;
    final number = request.from?.uri?.user;
    if (number == null) return;
    final state = '${request.getHeader('Subscription-State') ?? ''}'.toLowerCase();
    if (state.startsWith('terminated')) {
      // АТС закрыла подписку: статус больше не известен; при следующей регистрации подпишемся снова.
      _subscribed.remove(number);
      _setPresence(number, null);
      return;
    }
    if (_watched.contains(number)) _setPresence(number, presenceFromPidf(request.body));
  }

  void _setPresence(String number, Presence? status) {
    if (presence.value[number] == status) return;
    final next = {...presence.value};
    if (status == null) {
      next.remove(number);
    } else {
      next[number] = status;
    }
    presence.value = next;
  }

  @override
  void onNewReinvite(sip.ReInvite event) {}

  @override
  void dispose() {
    _connectTimer?.cancel();
    _connectingTimer?.cancel();
    _retryTimer?.cancel();
    for (final c in [_current, _other]) {
      try {
        _end(c);
      } catch (_) {
        // Звонок мог уже завершиться сам.
      }
    }
    _stop();
    unawaited(_webAudio?.dispose());
    super.dispose();
  }
}

/// Какие метки поставить в заголовок Replaces при переводе с консультацией.
///
/// [fromTag] и [toTag] — метки из заголовков From и To исходного INVITE этого звонка (так их хранит sip_ua).
/// В Replaces to-tag должен быть меткой АТС, а from-tag — нашей: АТС ищет разговор именно так
/// (RFC 3891; в Asterisk — `pjsip_ua_find_dialog(call_id, свой тег, чужой тег)`).
/// Когда звонили мы, наша метка стоит в From; когда звонили нам — в To, поэтому для входящего метки
/// меняются местами. Вынесено в отдельную функцию, чтобы это правило было закреплено тестом:
/// ошибка здесь проявляется только на живой АТС — «Соединить» молча не срабатывает.
@visibleForTesting
({String toTag, String fromTag}) replacesTags({
  required bool incoming,
  required String fromTag,
  required String toTag,
}) => incoming ? (toTag: fromTag, fromTag: toTag) : (toTag: toTag, fromTag: fromTag);

/// Что нужно sip_ua, чтобы собрать заголовок Replaces (refer_subscriber.dart, sendRefer: читает у объекта
/// call_id, to_tag и from_tag). Саму сессию передать нельзя: у RTCSession нет поля call_id.
///
/// По RFC 3891 to-tag — метка той стороны, которая получит Replaces (у нас это АТС), from-tag — наша.
/// У RTCSession from_tag/to_tag — метки из заголовков From/To исходного INVITE, поэтому для звонка,
/// который пришёл к нам, их нужно поменять местами.
class _ReplacesOf {
  _ReplacesOf(this.call_id, this.to_tag, this.from_tag);

  // Имена полей — как их читает sip_ua, поэтому не в принятом в Dart стиле.
  // ignore: non_constant_identifier_names
  final String call_id;
  // ignore: non_constant_identifier_names
  final String to_tag;
  // ignore: non_constant_identifier_names
  final String from_tag;

  static _ReplacesOf? from(dynamic session) {
    try {
      final callId = session.request?.call_id as String?;
      final fromTag = session.from_tag as String?;
      final toTag = session.to_tag as String?;
      if (callId == null || fromTag == null || toTag == null) return null;
      final tags = replacesTags(incoming: session.direction == sip.Direction.incoming, fromTag: fromTag, toTag: toTag);
      return _ReplacesOf(callId, tags.toTag, tags.fromTag);
    } catch (_) {
      return null;
    }
  }
}

/// Канал событий одного подключения к АТС (одного экземпляра sip_ua).
///
/// Пока подключение «живое», события идут в движок как обычно. После остановки из них нужны только два:
/// «регистрация снята» и «соединение закрыто» — по ним [SipEngine.sleep] понимает, что АТС получила запрос.
class _Link implements sip.SipUaHelperListener {
  _Link(this._engine, this.helper) {
    helper.addSipUaHelperListener(this);
  }

  final SipEngine _engine;
  final sip.SIPUAHelper helper;

  /// Этим экземпляром уже подключались — для следующего подключения нужен новый.
  bool used = false;

  /// Подключение действует: его события принадлежат движку.
  bool live = false;

  @override
  void transportStateChanged(sip.TransportState state) {
    if (live) {
      _engine.transportStateChanged(state);
    } else if (state.state == sip.TransportStateEnum.DISCONNECTED) {
      _engine._confirmUnregistered();
    }
  }

  @override
  void registrationStateChanged(sip.RegistrationState state) {
    if (live) {
      _engine.registrationStateChanged(state);
    } else if (state.state == sip.RegistrationStateEnum.UNREGISTERED) {
      _engine._confirmUnregistered();
    }
  }

  @override
  void callStateChanged(sip.Call call, sip.CallState state) {
    if (live) _engine.callStateChanged(call, state);
  }

  @override
  void onNewMessage(sip.SIPMessageRequest msg) {
    if (live) _engine.onNewMessage(msg);
  }

  @override
  void onNewNotify(sip.Notify ntf) {
    if (live) _engine.onNewNotify(ntf);
  }

  @override
  void onNewReinvite(sip.ReInvite event) {
    if (live) _engine.onNewReinvite(event);
  }
}

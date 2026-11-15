import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:logger/logger.dart';
import 'package:sip_ua/sip_ua.dart' as sip;

import '../state/account.dart';
import 'call_engine.dart';

/// Настоящие звонки: SIP поверх WebSocket (библиотека sip_ua), звук — WebRTC.
///
/// Приложение разговаривает с АТС тем же способом, что и софтфон в браузере:
/// телефон → WebSocket → Kamailio → Asterisk.
class SipEngine extends CallEngine implements sip.SipUaHelperListener {
  SipEngine() {
    _helper.addSipUaHelperListener(this);
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
  final sip.SIPUAHelper _helper = sip.SIPUAHelper(
    customLogger: Logger(
      level: _verbose ? Level.debug : Level.warning,
      filter: _verbose ? ProductionFilter() : null,
      printer: SimplePrinter(colors: false),
    ),
  );
  Account? _account;

  /// Мы сейчас сами снимаем удержание (см. обработку UNHOLD).
  bool _unholding = false;
  bool _keepTrying = false;
  bool _started = false;

  /// Сколько начатых вызовов человек отменил раньше, чем sip_ua успела их создать (см. CALL_INITIATION).
  int _cancelledDials = 0;

  /// Повтор регистрации после сбоя: sip_ua сама её не повторяет, пока соединение с сервером цело.
  Timer? _retryTimer;
  Duration _retryDelay = _retryMin;
  static const _retryMin = Duration(seconds: 5);
  static const _retryMax = Duration(seconds: 60);
  Completer<LinkStatus>? _firstResult;
  Timer? _connectTimer;

  sip.Call? _current;

  // В браузере звук собеседника сам не заиграет — его нужно отдать «проигрывателю».
  // На телефоне WebRTC играет звук сам, проигрыватель там не создаём.
  rtc.RTCVideoRenderer? _webAudio;

  @override
  Future<LinkStatus> connect(Account account, String password, {bool keepTrying = false}) {
    _account = account;
    _keepTrying = keepTrying;
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

    _connectTimer?.cancel();
    _connectTimer = Timer(_connectTimeout, () => _settle(const LinkStatus(LinkState.failed, LinkError.network)));

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

  void _stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!_started) return;
    _started = false;
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
        if (_current != null && _current!.id != sipCall.id) {
          // Второй звонок во время разговора пока не поддерживаем — отвечаем «занято».
          sipCall.hangup(<String, dynamic>{'status_code': 486});
          return;
        }
        if (sipCall.direction == sip.Direction.outgoing && _cancelledDials > 0) {
          // Человек нажал «Завершить» раньше, чем библиотека успела создать вызов. Отменяем его здесь,
          // иначе у собеседника зазвонил бы телефон, а у нас не было бы ни экрана, ни уведомления.
          _cancelledDials--;
          try {
            sipCall.hangup();
          } catch (_) {
            // Вызов мог ещё не дойти до состояния, из которого его можно отменить, — тогда он завершится сам.
          }
          return;
        }
        _current = sipCall;
        if (sipCall.direction == sip.Direction.incoming) {
          // Звонящий без номера приходит как «anonymous» — это не имя и не номер, показываем «Неизвестный номер».
          final raw = sipCall.remote_identity ?? '';
          final number = raw.toLowerCase() == 'anonymous' ? '' : raw;
          final rawName = sipCall.remote_display_name ?? '';
          final shown = rawName.toLowerCase() == 'anonymous' ? '' : rawName;
          call.value = CallInfo(
            phase: CallPhase.incoming,
            number: number,
            name: shown.isEmpty || shown == number ? null : shown,
            incoming: true,
            secure: _account?.secureTransport ?? false,
          );
        }
      case sip.CallStateEnum.ACCEPTED:
      case sip.CallStateEnum.CONFIRMED:
        if (!_isCurrent(sipCall)) return;
        final c = call.value;
        if (c != null && c.phase != CallPhase.active) {
          call.value = c.copyWith(phase: CallPhase.active, since: DateTime.now());
          // Звук пошёл — ещё раз говорим телефону, куда его выводить (к этому моменту его «звуковая часть»
          // точно запущена и послушается).
          unawaited(_setSpeakerphone(c.speaker));
          unawaited(_refreshRoutes());
        }
      case sip.CallStateEnum.STREAM:
        if (_isCurrent(sipCall) && state.originator == sip.Originator.remote) {
          unawaited(_playOnWeb(state.stream));
        }
      case sip.CallStateEnum.HOLD:
        if (_isCurrent(sipCall) && state.originator == sip.Originator.local) {
          call.value = call.value?.copyWith(held: true);
        }
      case sip.CallStateEnum.UNHOLD:
        // В sip_ua 1.1.0 у события «удержание снято» не заполнено, кто его снял (ошибка в библиотеке),
        // поэтому сами помним, что снимали мы. Иначе кнопка «Удержать» навсегда оставалась нажатой.
        if (_isCurrent(sipCall) && (_unholding || state.originator == sip.Originator.local)) {
          call.value = call.value?.copyWith(held: false);
        }
      case sip.CallStateEnum.MUTED:
      case sip.CallStateEnum.UNMUTED:
        if (_isCurrent(sipCall)) {
          call.value = call.value?.copyWith(muted: state.state == sip.CallStateEnum.MUTED);
        }
      case sip.CallStateEnum.FAILED:
        if (!_isCurrent(sipCall)) return;
        final failure = _failureOf(state);
        _clearCall();
        if (failure != null) reportFailure(failure);
      case sip.CallStateEnum.ENDED:
        if (_isCurrent(sipCall)) _clearCall();
      case sip.CallStateEnum.NONE:
      case sip.CallStateEnum.CONNECTING:
      case sip.CallStateEnum.PROGRESS:
      case sip.CallStateEnum.REFER:
        break;
    }
  }

  bool _isCurrent(sip.Call sipCall) => _current != null && _current!.id == sipCall.id;

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
    final hadSpeaker = call.value?.speaker ?? false;
    _current = null;
    call.value = null;
    _stopWatchingRoutes();
    if (hadSpeaker) unawaited(_setSpeakerphone(false));
    final player = _webAudio;
    if (player != null) player.srcObject = null;
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
    current.hangup(declining ? <String, dynamic>{'status_code': 603} : null);
  }

  @override
  void reject() {
    if (call.value?.phase == CallPhase.incoming) _current?.hangup(<String, dynamic>{'status_code': 486});
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
      _unholding = true;
      current.unhold();
      _unholding = false;
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

  // ---- Остальные события sip_ua нам не нужны ----

  @override
  void onNewMessage(sip.SIPMessageRequest msg) {}

  @override
  void onNewNotify(sip.Notify ntf) {}

  @override
  void onNewReinvite(sip.ReInvite event) {}

  @override
  void dispose() {
    _connectTimer?.cancel();
    _retryTimer?.cancel();
    _helper.removeSipUaHelperListener(this);
    try {
      _current?.hangup();
    } catch (_) {
      // Звонок мог уже завершиться сам.
    }
    _stop();
    unawaited(_webAudio?.dispose());
    super.dispose();
  }
}

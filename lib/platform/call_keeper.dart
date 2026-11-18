import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/push_info.dart';
import '../sip/call_engine.dart' show AudioKind, AudioRoute;

export '../data/push_info.dart';

/// «Сторож звонка»: всё, что делает сам телефон, чтобы приложение оставалось на связи в фоне,
/// звонило при входящем и не обрывало разговор. На Android это фоновая служба (CallService.kt).
abstract class CallKeeper {
  /// Нажата «Завершить» или «Отклонить» в уведомлении.
  VoidCallback? onHangUp;

  /// Нажата «Ответить» в уведомлении о входящем.
  VoidCallback? onAccept;

  /// Человек увидел окно приложения: уведомление о пропущенных убрано, счёт начинается заново.
  VoidCallback? onMissedSeen;

  /// Режим ожидания: тихое постоянное уведомление, приложение остаётся на связи в фоне.
  Future<void> standby({required String title, required String text});

  /// Входящий звонок: уведомление на весь экран с мелодией. [silent] — то же, но без звука и вибрации
  /// (человек нажал «Без звука»).
  Future<void> ring({
    required String title,
    required String text,
    required String acceptLabel,
    required String declineLabel,
    bool silent = false,
  });

  /// Идёт вызов или разговор: уведомление с кнопкой «Завершить», микрофон не отключается в фоне.
  Future<void> show({required String title, required String text, required String hangUpLabel});

  /// Открыта ссылка tel: или sip: — телефон просит подставить номер на экране набора (звонок не начинается).
  ValueChanged<String>? onDialRequest;

  /// Номер из ссылки, пришедшей, пока приложение запускалось. Возвращает его один раз и забывает.
  Future<String?> takePendingDial() async => null;

  /// Открыта ссылка настройки sado://login?… — передаётся как есть, разбирает её parseSetupLink.
  ValueChanged<String>? onSetupRequest;

  /// Ссылка настройки, пришедшая, пока приложение запускалось. Возвращает её один раз и забывает.
  Future<String?> takePendingSetup() async => null;

  /// Убирает уведомление и останавливает службу.
  Future<void> hide();

  /// Уведомление о пропущенном звонке (одно на все; телефон не показывает его, пока окно на экране).
  Future<void> missed({required String title, required String text}) async {}

  /// Убирает уведомление о пропущенных.
  Future<void> clearMissed() async {}

  /// Гасить ли экран, когда телефон поднесён к уху.
  Future<void> setProximity(bool on);

  /// Показывать ли окно приложения поверх экрана блокировки (на время звонка).
  Future<void> setOverLockScreen(bool on);

  /// Мелодия и вибрация входящих. Хранит их сам телефон: звонить должна фоновая служба, даже без окна.
  Future<RingSettings> ringSettings() async => const RingSettings();

  /// Открывает системный выбор мелодии; возвращает состояние после закрытия окна (прежнее, если передумали).
  Future<RingSettings> pickRingtone() async => const RingSettings();

  /// Открывает сканер QR-кода (экран с камерой) и ждёт, пока код прочитан или экран закрыт.
  /// [hint] — подсказка на экране сканера, [close] — надпись кнопки закрытия.
  /// Там, где сканера нет (не Android), сразу отвечает [QrScanStatus.unavailable].
  Future<QrScan> scanQr({required String hint, required String close}) async => const QrScan(QrScanStatus.unavailable);

  /// Включает или выключает вибрацию при входящем; возвращает новое состояние.
  Future<RingSettings> setRingVibration(bool on) async => const RingSettings();

  /// Снято ли с приложения ограничение батареи.
  Future<bool> batteryUnrestricted();

  /// Открывает системное окно, где это ограничение снимается.
  Future<void> askBatteryExemption();

  /// Есть ли у телефона свой запрет «Автозапуск» (Xiaomi, Redmi, POCO).
  Future<bool> hasAutostartSettings() async => false;

  /// Открывает экран, где этот запрет снимается.
  Future<void> openAutostartSettings() async {}

  /// Разрешены ли приложению уведомления. Без них входящий не звонит и не показывается.
  Future<bool> notificationsAllowed() async => true;

  /// Открывает системный экран уведомлений приложения.
  Future<void> openNotificationSettings() async {}

  /// Разрешено ли показывать экран звонка поверх экрана блокировки (с Android 14 — отдельное разрешение).
  Future<bool> canFullScreenIntent() async => true;

  /// Открывает системный экран с этим разрешением.
  Future<void> openFullScreenSettings() async {}

  /// Сведения для АТС о том, как будить этот телефон push-уведомлением; null — push здесь нет
  /// (сборка без сервисов Google, телефон без них или не Android).
  Future<PushInfo?> pushInfo() async => null;

  /// Не разбудил ли приложение только что push «проснись» (пока код Dart ещё не был запущен).
  /// Спрашивается один раз при запуске; повторный вопрос отвечает «нет».
  Future<bool> takePushWake() async => false;

  /// Пришёл push «проснись», когда код Dart уже работал.
  void Function()? onPushWake;

  /// Адрес телефона для push сменился — АТС нужно сообщить новый ([pushInfo]).
  void Function()? onPushTokenChanged;

  // ---- Система звонков телефона (пробный режим «Системные звонки») ----

  /// Умеет ли телефон вести звонки приложения в своей системе звонков: тогда работают кнопка гарнитуры,
  /// машина и часы, а сотовый звонок не отбирает звук молча.
  Future<bool> systemCallsSupported() async => false;

  /// Появился звонок [id] ([CallInfo.id]) — сообщаем системе.
  Future<void> systemCallStart({required int id, required String number, String? name, required bool incoming}) async {}

  /// Звонок соединён ([held] = false) или поставлен на удержание.
  Future<void> systemCallState(int id, {required bool held}) async {}

  /// Звонок закончился.
  Future<void> systemCallEnd(int id, SystemCallEnd reason) async {}

  /// Человек выбрал, куда выводить звук этого звонка.
  Future<void> systemCallRoute(int id, AudioKind kind) async {}

  /// Система просит что-то сделать со звонком (нажата кнопка гарнитуры, пришёл сотовый звонок и т. п.).
  void Function(int id, SystemCallAction action)? onSystemCall;

  /// Система назвала устройства звука для звонка и то, которое выбрано сейчас.
  void Function(int id, List<AudioRoute> routes, AudioKind? current)? onSystemRoutes;

  /// Система больше не ведёт этот звонок (он закончился или она его не приняла).
  void Function(int id)? onSystemCallGone;

  /// Какой значок сейчас стоит на рабочем столе; null — значок выбирать нельзя.
  Future<String?> appIcon() async => null;

  /// Меняет значок на рабочем столе.
  Future<void> setAppIcon(String name) async {}

  /// Открывает страницу в браузере телефона (страница выпуска на GitHub).
  Future<void> openUrl(String url) async {}
}

/// Там, где сторож не нужен или его нет (браузер), ничего не делает.
class NoopCallKeeper extends CallKeeper {
  @override
  Future<void> standby({required String title, required String text}) async {}

  @override
  Future<void> ring({
    required String title,
    required String text,
    required String acceptLabel,
    required String declineLabel,
    bool silent = false,
  }) async {}

  @override
  Future<void> show({required String title, required String text, required String hangUpLabel}) async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> setProximity(bool on) async {}

  @override
  Future<void> setOverLockScreen(bool on) async {}

  @override
  Future<bool> batteryUnrestricted() async => true;

  @override
  Future<void> askBatteryExemption() async {}
}

class AndroidCallKeeper extends CallKeeper {
  AndroidCallKeeper() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'hangUp':
          onHangUp?.call();
        case 'accept':
          onAccept?.call();
        case 'missedSeen':
          onMissedSeen?.call();
        case 'dialRequest':
          final number = call.arguments;
          if (number is String) onDialRequest?.call(number);
          // Номер уже доставлен событием — убираем его из очереди, чтобы он не всплыл при следующем запуске.
          unawaited(takePendingDial());
        case 'pushWake':
          onPushWake?.call();
        case 'systemCall':
          final args = call.arguments;
          if (args is Map && args['id'] is int) {
            final action = SystemCallAction.values.asNameMap()[args['action']];
            if (action != null) onSystemCall?.call(args['id'] as int, action);
          }
        case 'systemRoutes':
          final args = call.arguments;
          if (args is Map && args['id'] is int) {
            final kinds = AudioKind.values.asNameMap();
            final routes = <AudioRoute>[];
            for (final item in args['routes'] is List ? args['routes'] as List : const <Object?>[]) {
              if (item is! Map) continue;
              final kind = kinds[item['kind']];
              final name = item['name'];
              // Одно устройство каждого вида, как и в обычном списке; имя нужно только гарнитуре Bluetooth.
              if (kind == null || routes.any((r) => r.kind == kind)) continue;
              routes.add(
                AudioRoute(kind, kind == AudioKind.bluetooth && name is String && name.isNotEmpty ? name : null),
              );
            }
            routes.sort((a, b) => a.kind.index.compareTo(b.kind.index));
            onSystemRoutes?.call(args['id'] as int, routes, kinds[args['current']]);
          }
        case 'systemCallGone':
          final id = call.arguments;
          if (id is int) onSystemCallGone?.call(id);
        case 'pushToken':
          onPushTokenChanged?.call();
        case 'setupRequest':
          final link = call.arguments;
          if (link is String) onSetupRequest?.call(link);
          // Так же: ссылка доставлена, в очереди её держать незачем (в ней может быть пароль).
          unawaited(takePendingSetup());
      }
    });
  }

  static const _channel = MethodChannel('uz.sado.app/call');

  /// Сбой на стороне телефона не должен ронять звонок: без сторожа он просто
  /// оборвётся при сворачивании, как раньше.
  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null; // телефон отказал (например, служба запрещена настройками)
    } on MissingPluginException {
      return null; // запущено не на Android
    }
  }

  @override
  Future<void> standby({required String title, required String text}) =>
      _invoke<void>('standby', {'title': title, 'text': text});

  @override
  Future<void> ring({
    required String title,
    required String text,
    required String acceptLabel,
    required String declineLabel,
    bool silent = false,
  }) => _invoke<void>('ring', {
    'title': title,
    'text': text,
    'primary': acceptLabel,
    'secondary': declineLabel,
    'silent': silent,
  });

  @override
  Future<void> show({required String title, required String text, required String hangUpLabel}) =>
      _invoke<void>('show', {'title': title, 'text': text, 'primary': hangUpLabel});

  @override
  Future<String?> takePendingDial() => _invoke<String>('takePendingDial');

  @override
  Future<String?> takePendingSetup() => _invoke<String>('takePendingSetup');

  @override
  Future<void> hide() => _invoke<void>('hide');

  @override
  Future<void> missed({required String title, required String text}) =>
      _invoke<void>('missed', {'title': title, 'text': text});

  @override
  Future<void> clearMissed() => _invoke<void>('clearMissed');

  @override
  Future<void> setProximity(bool on) => _invoke<void>('proximity', on);

  @override
  Future<void> setOverLockScreen(bool on) => _invoke<void>('lockScreen', on);

  @override
  Future<RingSettings> ringSettings() async => RingSettings.fromMap(await _invoke<Object?>('ringSettings'));

  @override
  Future<RingSettings> pickRingtone() async => RingSettings.fromMap(await _invoke<Object?>('pickRingtone'));

  @override
  Future<PushInfo?> pushInfo() async => PushInfo.fromMap(await _invoke<Object?>('pushInfo'));

  @override
  Future<bool> takePushWake() async => await _invoke<bool>('takePushWake') ?? false;

  @override
  Future<QrScan> scanQr({required String hint, required String close}) async =>
      QrScan.fromMap(await _invoke<Object?>('scanQr', {'hint': hint, 'close': close}));

  @override
  Future<RingSettings> setRingVibration(bool on) async =>
      RingSettings.fromMap(await _invoke<Object?>('setRingVibration', on));

  @override
  Future<bool> batteryUnrestricted() async => await _invoke<bool>('batteryUnrestricted') ?? true;

  @override
  Future<void> askBatteryExemption() => _invoke<void>('askBattery');

  @override
  Future<bool> hasAutostartSettings() async => await _invoke<bool>('hasAutostart') ?? false;

  @override
  Future<void> openAutostartSettings() => _invoke<void>('openAutostart');

  @override
  Future<bool> notificationsAllowed() async => await _invoke<bool>('notificationsAllowed') ?? true;

  @override
  Future<void> openNotificationSettings() => _invoke<void>('openNotifications');

  @override
  Future<bool> canFullScreenIntent() async => await _invoke<bool>('canFullScreen') ?? true;

  @override
  Future<void> openFullScreenSettings() => _invoke<void>('openFullScreen');

  @override
  Future<bool> systemCallsSupported() async => await _invoke<bool>('systemCallsSupported') ?? false;

  @override
  Future<void> systemCallStart({required int id, required String number, String? name, required bool incoming}) =>
      _invoke<void>('systemCallStart', {'id': id, 'number': number, 'name': name, 'incoming': incoming});

  @override
  Future<void> systemCallState(int id, {required bool held}) =>
      _invoke<void>('systemCallState', {'id': id, 'held': held});

  @override
  Future<void> systemCallEnd(int id, SystemCallEnd reason) =>
      _invoke<void>('systemCallEnd', {'id': id, 'reason': reason.name});

  @override
  Future<void> systemCallRoute(int id, AudioKind kind) =>
      _invoke<void>('systemCallRoute', {'id': id, 'kind': kind.name});

  @override
  Future<String?> appIcon() => _invoke<String>('appIcon');

  @override
  Future<void> setAppIcon(String name) => _invoke<void>('setAppIcon', name);

  // Свой метод вместо пакета url_launcher: нужен один вызов, а адрес телефон ещё раз сверяет сам.
  @override
  Future<void> openUrl(String url) => _invoke<void>('openUrl', url);
}

/// Чем закончился звонок — для системы звонков телефона.
enum SystemCallEnd {
  /// Положили трубку мы (или причина неизвестна).
  local,

  /// Положил трубку собеседник.
  remote,

  /// Входящий отклонён.
  rejected,

  /// На входящий не ответили.
  missed,
}

/// Что система звонков телефона просит сделать со звонком.
enum SystemCallAction { answer, hangUp, hold, unhold }

/// Чем закончилось сканирование QR-кода.
enum QrScanStatus {
  /// Код прочитан, его текст — в [QrScan.text].
  ok,

  /// Человек закрыл сканер.
  cancelled,

  /// Камеры нет или к ней не дали доступ.
  denied,

  /// Сканера на этой платформе нет.
  unavailable,
}

class QrScan {
  const QrScan(this.status, [this.text]);

  /// Разбирает ответ телефона; непонятный ответ считаем «сканера нет».
  factory QrScan.fromMap(Object? raw) {
    if (raw is! Map) return const QrScan(QrScanStatus.unavailable);
    final text = raw['text'];
    return switch (raw['status']) {
      'ok' when text is String && text.isNotEmpty => QrScan(QrScanStatus.ok, text),
      'denied' => const QrScan(QrScanStatus.denied),
      'ok' || 'cancelled' => const QrScan(QrScanStatus.cancelled),
      _ => const QrScan(QrScanStatus.unavailable),
    };
  }

  final QrScanStatus status;
  final String? text;
}

/// Мелодия и вибрация входящих звонков, как их видит телефон.
class RingSettings {
  const RingSettings({this.title, this.vibrate = true});

  /// Из ответа телефона; если ответа нет (сбой, не Android) — значения по умолчанию.
  factory RingSettings.fromMap(Object? raw) {
    if (raw is! Map) return const RingSettings();
    final title = raw['title'];
    final vibrate = raw['vibrate'];
    return RingSettings(title: title is String ? title : null, vibrate: vibrate is bool ? vibrate : true);
  }

  /// Название выбранной мелодии; null — системная мелодия звонка («как в телефоне»).
  final String? title;

  /// Вибрировать ли при входящем.
  final bool vibrate;
}

final callKeeperProvider = Provider<CallKeeper>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? AndroidCallKeeper() : NoopCallKeeper(),
);

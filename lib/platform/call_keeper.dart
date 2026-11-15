import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Future<String?> appIcon() => _invoke<String>('appIcon');

  @override
  Future<void> setAppIcon(String name) => _invoke<void>('setAppIcon', name);

  // Свой метод вместо пакета url_launcher: нужен один вызов, а адрес телефон ещё раз сверяет сам.
  @override
  Future<void> openUrl(String url) => _invoke<void>('openUrl', url);
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

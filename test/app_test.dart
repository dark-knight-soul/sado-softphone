import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/data/demo_data.dart';
import 'package:sado/l10n/strings.dart';
import 'package:sado/platform/call_keeper.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/call.dart';
import 'package:sado/state/password_store.dart';
import 'package:sado/state/session.dart';
import 'package:sado/state/settings.dart';
import 'package:sado/theme/sado_icons.dart';
import 'package:sado/theme/sado_style.dart';
import 'package:sado/theme/styles.dart';
import 'package:sado/ui/pill_answer.dart';
import 'package:sado/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Движок, который на подключение отвечает заданным итогом (например, «неверный пароль»).
class FixedLinkEngine extends DemoEngine {
  FixedLinkEngine(this.result);

  final LinkStatus result;

  @override
  Future<LinkStatus> connect(Account account, String password, {bool keepTrying = false, PushInfo? push}) async {
    link.value = result;
    return result;
  }
}

/// «Сторож звонка», который ничего не делает на телефоне, а записывает, что его просили.
class RecordingKeeper extends CallKeeper {
  final log = <String>[];

  /// Что отвечать на вопрос «снято ли ограничение батареи».
  bool unrestricted = false;

  /// Номер из ссылки tel:/sip:, «пришедшей» до запуска; задаётся в [pendingDialOnStart] до pumpApp.
  String? pendingDial = pendingDialOnStart;

  @override
  Future<String?> takePendingDial() async {
    final number = pendingDial;
    pendingDial = null;
    return number;
  }

  /// Push на «телефоне»: сведения для АТС (null — push нет) и «приложение запущено push-уведомлением».
  PushInfo? push = pushOnStart;
  bool wokenByPush = wokenByPushOnStart;

  @override
  Future<PushInfo?> pushInfo() async => push;

  @override
  Future<bool> takePushWake() async {
    final woken = wokenByPush;
    wokenByPush = false;
    return woken;
  }

  /// Что «ответит сканер» QR-кода; тест задаёт это перед нажатием кнопки.
  QrScan scanAnswer = const QrScan(QrScanStatus.unavailable);

  @override
  Future<QrScan> scanQr({required String hint, required String close}) async {
    log.add('scan: $hint | $close');
    return scanAnswer;
  }

  /// Ссылка настройки, «пришедшая» до запуска; задаётся в [pendingSetupOnStart] до pumpApp.
  String? pendingSetup = pendingSetupOnStart;

  @override
  Future<String?> takePendingSetup() async {
    final link = pendingSetup;
    pendingSetup = null;
    return link;
  }

  @override
  Future<void> standby({required String title, required String text}) async => log.add('standby: $text');

  @override
  Future<void> ring({
    required String title,
    required String text,
    required String acceptLabel,
    required String declineLabel,
    bool silent = false,
  }) async => log.add('ring: $title | $text | $acceptLabel | $declineLabel${silent ? ' | без звука' : ''}');

  @override
  Future<void> show({required String title, required String text, required String hangUpLabel}) async =>
      log.add('show: $title | $text | $hangUpLabel');

  @override
  Future<void> hide() async => log.add('hide');

  @override
  Future<void> setProximity(bool on) async => log.add('proximity: $on');

  @override
  Future<void> setOverLockScreen(bool on) async => log.add('lock: $on');

  /// Мелодия и вибрация «на телефоне»; [pickedRingtone] — что «выберет» человек в системном окне.
  RingSettings ringState = const RingSettings();
  String? pickedRingtone = 'Звонок 1';

  @override
  Future<RingSettings> ringSettings() async => ringState;

  @override
  Future<RingSettings> pickRingtone() async {
    log.add('pickRingtone');
    return ringState = RingSettings(title: pickedRingtone, vibrate: ringState.vibrate);
  }

  @override
  Future<RingSettings> setRingVibration(bool on) async {
    log.add('setRingVibration: $on');
    return ringState = RingSettings(title: ringState.title, vibrate: on);
  }

  @override
  Future<bool> batteryUnrestricted() async => unrestricted;

  @override
  Future<void> askBatteryExemption() async => log.add('askBattery');

  @override
  Future<void> missed({required String title, required String text}) async => log.add('missed: $title | $text');

  @override
  Future<void> clearMissed() async => log.add('clearMissed');

  @override
  Future<void> openUrl(String url) async => log.add('openUrl: $url');
}

/// Что новый [RecordingKeeper] вернёт как «номер из ссылки при запуске» (тесты открытия ссылок).
String? pendingDialOnStart;

/// Push у нового [RecordingKeeper]: есть ли он на «телефоне» и запущено ли приложение push-уведомлением.
/// Сбрасываются после каждого запуска приложения в тесте.
PushInfo? pushOnStart;
bool wokenByPushOnStart = false;

/// Что новый [RecordingKeeper] вернёт как «ссылку настройки при запуске» (тесты входа по ссылке).
String? pendingSetupOnStart;

/// Сторож последнего запущенного приложения — чтобы тест мог посмотреть его записи.
late RecordingKeeper keeper;

/// Имитация, которая запоминает, куда перевели звонок и сколько входящих отклонили «занято».
class _TransferSpy extends DemoEngine {
  String? transferredTo;
  int rejected = 0;

  @override
  void transfer(String target) {
    transferredTo = target;
    super.transfer(target);
  }

  @override
  void reject() {
    rejected++;
    super.reject();
  }
}

/// Запускает приложение. Настоящий SIP в тестах не используется: движок всегда имитация,
/// пароль хранится в памяти.
Future<MemoryPasswordStore> pumpApp(
  WidgetTester tester, {
  Map<String, Object> saved = const {},
  CallEngine Function(Account)? engine,
  String? savedPassword,
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final passwords = MemoryPasswordStore(savedPassword);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        passwordStoreProvider.overrideWithValue(passwords),
        engineFactoryProvider.overrideWithValue(engine ?? (_) => DemoEngine()),
        callKeeperProvider.overrideWithValue(keeper = RecordingKeeper()),
      ],
      child: const SadoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return passwords;
}

/// Демонстрационная учётная запись: с образцом контактов и истории.
const demoAccount = <String, Object>{'account.server': 'demo', 'account.number': '1003', 'lang': 'ru'};

/// Обычная учётная запись (в тестах её звонки тоже ведёт имитация).
const realAccount = <String, Object>{'account.server': 'sado.test', 'account.number': '1003', 'lang': 'ru'};

SadoStyle styleOf(WidgetTester tester) => SadoStyle.of(tester.element(find.byType(Scaffold).first));

/// Прокручиваемая область списка с данным ключом (на экране их несколько).
Finder scrollableOf(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(Scrollable)).first;

/// Набирает номер и ждёт, пока имитация «ответит».
Future<void> callAndAnswer(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Key('key.$d')));
  }
  await tester.tap(find.byKey(const Key('dialer.call')));
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
}

/// Выбирает вариант в настройке со списком: докручивает до строки, нажимает её и нужный вариант.
Future<void> pick(WidgetTester tester, String rowKey, String option) async {
  final row = find.byKey(Key(rowKey));
  await tester.scrollUntilVisible(row, 120, scrollable: scrollableOf('settings.list'));
  await tester.tap(row);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Показывает входящий звонок (как кнопка «Показать входящий звонок» в демонстрации).
/// Пока экран входящего на виду, нельзя ждать «полной остановки» анимаций: ручка свайпа качается постоянно.
Future<void> ringIn(WidgetTester tester) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(SadoApp)));
  container.read(callProvider.notifier).simulateIncoming(number: '1002', name: 'Азиз Каримов');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('formatNumber: девять цифр разбивает, остальное не трогает', () {
    expect(formatNumber('901234567'), '90 123 45 67');
    expect(formatNumber('1002'), '1002');
    expect(formatNumber('+99890123'), '+99890123');
    expect(formatNumber(''), '');
  });

  test('dialTarget: в адрес вызова попадают только знаки номера', () {
    expect(dialTarget('1002'), '1002');
    expect(dialTarget('+998 (90) 123-45-67'), '+99890123-45-67');
    expect(dialTarget('*43#'), '*43#');
    expect(dialTarget('reception'), 'reception');
    // Строка из контакта не должна увести вызов на посторонний сервер.
    expect(dialTarget('100@evil.example;transport=tcp'), '100evil.exampletransporttcp');
    expect(dialTarget('sip:100@host'), 'sip100host');
    expect(dialTarget(' <> '), '');
  });

  testWidgets('звонок закрывает окна, открытые поверх: экран входящего не остаётся под ними', (tester) async {
    await pumpApp(tester, saved: demoAccount);
    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contacts.add')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    await ringIn(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('call.accept')), findsOneWidget);
    // Кнопка «Принять» действительно доступна для нажатия, а не закрыта чем-то сверху.
    await tester.tap(find.byKey(const Key('call.accept')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);
  });

  testWidgets('клавиши в разговоре помещаются на коротком экране с полосами системы', (tester) async {
    for (final id in SadoStyleId.values) {
      await pumpApp(tester, saved: {...demoAccount, 'style': id.name}, size: const Size(320, 568));
      // Строка состояния сверху и три кнопки навигации снизу — как на недорогом телефоне.
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('tab.${AppTab.dial.index}')));
      await tester.pumpAndSettle();
      // Звонок сохранённому контакту: под именем добавляется строка с номером — самый высокий вариант шапки.
      await callAndAnswer(tester, '1002');
      await tester.tap(find.byKey(const Key('call.keypad')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: id.name);
      final hangup = tester.getRect(find.byKey(const Key('call.hangup')));
      expect(hangup.bottom, lessThanOrEqualTo(568 - 48), reason: '${id.name}: «Завершить» над полосой навигации');
      await tester.tap(find.byKey(const Key('call.hangup')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('экран входа предупреждает о незашифрованном адресе ws://', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    expect(find.byKey(const Key('login.insecure')), findsNothing);
    await tester.enterText(find.byKey(const Key('login.server')), 'ws://192.0.2.10:5066');
    await tester.pump();
    expect(find.byKey(const Key('login.insecure')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login.server')), 'wss://pbx.example.com/ws');
    await tester.pump();
    expect(find.byKey(const Key('login.insecure')), findsNothing);
    await tester.enterText(find.byKey(const Key('login.server')), 'pbx.example.com');
    await tester.pump();
    expect(find.byKey(const Key('login.insecure')), findsNothing);
  });

  test('Avatar.initials: две буквы из имени, пусто для номера', () {
    expect(Avatar.initials('Азиз Каримов'), 'АК');
    expect(Avatar.initials('Склад'), 'С');
    expect(Avatar.initials('905550122'), '');
  });

  test('у каждого стиля есть описание, и все пять на месте', () {
    expect(sadoStyles.map((s) => s.id).toSet(), SadoStyleId.values.toSet());
    for (final id in SadoStyleId.values) {
      expect(buildTheme(styleSpecOf(id), Brightness.light).extension<SadoStyle>()!.id, id);
      expect(buildTheme(styleSpecOf(id), Brightness.dark).extension<SadoStyle>()!.id, id);
    }
  });

  test('Account: адрес WebSocket и домен из того, что ввёл человек', () {
    const byName = Account(server: 'sado.company.uz', number: '1003');
    expect(byName.wsUrl, 'wss://sado.company.uz/ws');
    expect(byName.domain, 'sado.company.uz');
    expect(byName.secureTransport, isTrue);
    expect(byName.isDemo, isFalse);

    const full = Account(server: 'ws://192.0.2.10:8080/ws', number: '1007');
    expect(full.wsUrl, 'ws://192.0.2.10:8080/ws');
    expect(full.domain, '192.0.2.10');
    expect(full.secureTransport, isFalse);

    const withPort = Account(server: ' sado.company.uz:8443 ', number: '1003');
    expect(withPort.wsUrl, 'wss://sado.company.uz:8443/ws');
    expect(withPort.domain, 'sado.company.uz');

    expect(const Account(server: ' Demo ', number: '1003').isDemo, isTrue);
  });

  test('история: запись переживает сохранение и чтение', () {
    final e = HistoryEntry(name: 'Склад', number: '1010', kind: CallKind.missed, at: DateTime(2026, 11, 14, 12, 40));
    final back = HistoryEntry.fromJson(e.toJson());
    expect((back.name, back.number, back.kind, back.seconds, back.at), (e.name, e.number, e.kind, 0, e.at));
    expect(dayLabelOf(DateTime(2026, 11, 14, 0, 5), DateTime(2026, 11, 14, 23)), DayLabel.today);
    expect(dayLabelOf(DateTime(2026, 11, 13, 23, 59), DateTime(2026, 11, 14, 0, 1)), DayLabel.yesterday);
    expect(dayLabelOf(DateTime(2026, 11, 10), DateTime(2026, 11, 14)), DayLabel.earlier);
    expect(splitDuration(42), (value: 42, minutes: false));
    expect(splitDuration(240), (value: 4, minutes: true));
  });

  testWidgets('вход: пустые поля не пускают; успешный вход прячет пароль в защищённое хранилище', (tester) async {
    final passwords = await pumpApp(tester, saved: {'lang': 'ru'});
    expect(find.text('Телефон вашей компании'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Заполните поле'), findsNWidgets(3));

    await tester.enterText(find.byKey(const Key('login.server')), 'sado.test');
    await tester.enterText(find.byKey(const Key('login.number')), '1003');
    await tester.enterText(find.byKey(const Key('login.password')), 'secret');
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(find.text('1003 · на связи'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account.number'), '1003');
    expect(passwords.value, 'secret');
    // В обычные настройки пароль не пишется.
    expect(prefs.getKeys().any((k) => prefs.get(k) == 'secret'), isFalse);
  });

  testWidgets('вход: при неверном пароле остаёмся на экране входа и видим причину', (tester) async {
    final passwords = await pumpApp(
      tester,
      saved: {'lang': 'ru'},
      engine: (_) => FixedLinkEngine(const LinkStatus(LinkState.failed, LinkError.auth)),
    );
    await tester.enterText(find.byKey(const Key('login.server')), 'sado.test');
    await tester.enterText(find.byKey(const Key('login.number')), '1003');
    await tester.enterText(find.byKey(const Key('login.password')), 'wrong');
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Неверный номер или пароль'), findsOneWidget);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account.number'), isNull);
    expect(passwords.value, isNull);
  });

  testWidgets('вход: кнопка «Посмотреть без сервера» открывает демонстрацию', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    await tester.ensureVisible(find.byKey(const Key('login.demo')));
    await tester.tap(find.byKey(const Key('login.demo')));
    await tester.pumpAndSettle();
    expect(find.text('1003 · на связи'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    expect(find.text('Азиз Каримов'), findsOneWidget);
  });

  testWidgets('сохранённая учётная запись: при запуске подключается сама; без пароля — просит войти', (tester) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');
    expect(find.text('1003 · на связи'), findsOneWidget);

    await pumpApp(tester, saved: realAccount);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
  });

  testWidgets('нет связи с АТС: строка состояния говорит об этом честно', (tester) async {
    await pumpApp(
      tester,
      saved: realAccount,
      savedPassword: 'secret',
      engine: (_) => FixedLinkEngine(const LinkStatus(LinkState.failed, LinkError.network)),
    );
    expect(find.text('1003 · нет связи'), findsOneWidget);
    expect(find.text('1003 · на связи'), findsNothing);
  });

  testWidgets('набор: цифры, стирание, звонок, удержание, донабор и завершение', (tester) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');

    for (final d in '901234567'.split('')) {
      await tester.tap(find.byKey(Key('key.$d')));
    }
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('dialer.number'))).data, '90 123 45 67');

    await tester.tap(find.byKey(const Key('dialer.backspace')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('dialer.number'))).data, '90123456');

    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Вызов…'), findsOneWidget);

    // Через две секунды имитация «отвечает» — появляется таймер разговора.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Вызов…'), findsNothing);
    expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call.hold')));
    await tester.pump();
    expect(find.text('На удержании'), findsOneWidget);

    await tester.tap(find.byKey(const Key('call.keypad')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dtmf.1')));
    await tester.tap(find.byKey(const Key('dtmf.#')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('call.tones'))).data, '1#');
    await tester.tap(find.byKey(const Key('call.keypadClose')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('call.hangup')), findsNothing);
    expect(find.text('1003 · на связи'), findsOneWidget);
  });

  testWidgets('в фоне: режим ожидания «на связи», уведомление о разговоре и возврат в ожидание', (tester) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');
    // Вошли — приложение сразу встаёт в режим ожидания и остаётся на связи в фоне.
    expect(keeper.log.last, 'standby: 1003 · на связи');

    for (final d in '1002'.split('')) {
      await tester.tap(find.byKey(Key('key.$d')));
    }
    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump(const Duration(milliseconds: 300));
    // Пошёл вызов: уведомление с «Завершить», экран у уха гаснет, окно разрешено поверх блокировки.
    expect(keeper.log.sublist(keeper.log.length - 3), [
      'show: 1002 | Вызов… | Завершить',
      'proximity: true',
      'lock: true',
    ]);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(keeper.log.last, 'show: 1002 | Идёт разговор | Завершить');

    // Громкая связь: телефон лежит на столе, экран гасить не нужно.
    await tester.tap(find.byKey(const Key('call.speaker')));
    await tester.pump();
    expect(keeper.log.last, 'proximity: false');
    await tester.tap(find.byKey(const Key('call.speaker')));
    await tester.pump();
    expect(keeper.log.last, 'proximity: true');

    await tester.tap(find.byKey(const Key('call.hold')));
    await tester.pump();
    expect(keeper.log.last, 'show: 1002 | На удержании | Завершить');

    // Отключение микрофона уведомление не трогает — лишний раз телефон не дёргаем.
    final before = keeper.log.length;
    await tester.tap(find.byKey(const Key('call.mute')));
    await tester.pump();
    expect(keeper.log.length, before);

    // «Завершить» в уведомлении завершает звонок так же, как красная кнопка; служба возвращается в ожидание.
    keeper.onHangUp!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('call.hangup')), findsNothing);
    expect(keeper.log.sublist(keeper.log.length - 3), ['standby: 1003 · на связи', 'proximity: false', 'lock: false']);
    expect(keeper.log.contains('hide'), isFalse);
  });

  testWidgets('в фоне: входящий звонит на весь экран, «Ответить» в уведомлении начинает разговор', (tester) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');

    await ringIn(tester);
    expect(keeper.log.contains('ring: Азиз Каримов | Входящий звонок | Принять | Отклонить'), isTrue);
    // При входящем экран у уха не гасим — на него нужно смотреть.
    expect(keeper.log.contains('proximity: true'), isFalse);
    expect(keeper.log.last, 'lock: true');

    keeper.onAccept!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);
    expect(keeper.log.contains('show: Азиз Каримов | Идёт разговор | Завершить'), isTrue);

    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();
    expect(keeper.log.contains('standby: 1003 · на связи'), isTrue);
  });

  testWidgets('в фоне: настройку можно выключить — служба останавливается; ограничение батареи снимается кнопкой', (
    tester,
  ) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.battery')),
      120,
      scrollable: scrollableOf('settings.list'),
    );
    await tester.tap(find.byKey(const Key('settings.battery')));
    await tester.pump();
    expect(keeper.log.last, 'askBattery');

    await tester.tap(find.text('Не принимать'));
    await tester.pumpAndSettle();
    expect(keeper.log.last, 'hide');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('backgroundLink'), isFalse);
    // Кнопка про батарею без фоновой работы не нужна.
    expect(find.byKey(const Key('settings.battery')), findsNothing);

    await tester.tap(find.text('Принимать'));
    await tester.pumpAndSettle();
    expect(keeper.log.last, 'standby: 1003 · на связи');
  });

  testWidgets('в фоне: нет связи — уведомление говорит об этом; в демонстрации служба не запускается', (tester) async {
    await pumpApp(
      tester,
      saved: realAccount,
      savedPassword: 'secret',
      engine: (_) => FixedLinkEngine(const LinkStatus(LinkState.failed, LinkError.network)),
    );
    expect(keeper.log.last, 'standby: 1003 · нет связи');

    await pumpApp(tester, saved: demoAccount);
    // Служба не запускается; единственное, что делает приложение, — останавливает её на случай,
    // если её подняла перезагрузка телефона.
    expect(keeper.log, ['hide']);
    await callAndAnswer(tester, '5');
    expect(keeper.log.any((e) => e.startsWith('show:')), isTrue);
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();
    // В демонстрации после звонка служба останавливается совсем (первая остановка — при запуске, см. выше).
    expect(keeper.log.where((e) => e == 'hide').length, 2);
  });

  testWidgets('выход посреди звонка убирает уведомление', (tester) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');
    await callAndAnswer(tester, '5');
    expect(keeper.log.any((e) => e.startsWith('show:')), isTrue);
    expect(keeper.log.contains('hide'), isFalse);

    final container = ProviderScope.containerOf(tester.element(find.byType(SadoApp)));
    await container.read(sessionProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(keeper.log.contains('hide'), isTrue);
    expect(keeper.log.last, 'lock: false');
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
  });

  testWidgets('настоящая учётная запись: звонок попадает в историю и сохраняется, контакты честно пусты', (
    tester,
  ) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');

    await tester.tap(find.byKey(const Key('tab.1')));
    await tester.pumpAndSettle();
    expect(find.text('Здесь появятся ваши звонки'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    await callAndAnswer(tester, '1002');
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab.1')));
    await tester.pumpAndSettle();
    expect(find.text('Здесь появятся ваши звонки'), findsNothing);
    expect(find.text('1002'), findsOneWidget);
    expect(find.textContaining('сек'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('history'), contains('"number":"1002"'));
    expect(prefs.getString('history'), contains('"kind":"outgoing"'));

    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contacts.empty')), findsOneWidget);
    expect(find.text('Азиз Каримов'), findsNothing);

    // У настоящей учётной записи раздела «Демонстрация» нет.
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings.demoIncoming')), findsNothing);
  });

  testWidgets('выход стирает учётную запись, пароль и историю', (tester) async {
    final passwords = await pumpApp(
      tester,
      saved: {...realAccount, 'history': '[{"number":"1002","kind":"outgoing","seconds":5,"at":1}]'},
      savedPassword: 'secret',
    );
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    // Кнопка выхода ниже по списку — сначала докручиваем до неё.
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.signOut')),
      120,
      scrollable: scrollableOf('settings.list'),
    );
    await tester.tap(find.byKey(const Key('settings.signOut')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login.submit')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account.number'), isNull);
    expect(prefs.getString('history'), isNull);
    expect(passwords.value, isNull);
  });

  testWidgets('входящий звонок (демонстрация): принять — начинается разговор', (tester) async {
    await pumpApp(tester, saved: demoAccount);

    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.demoIncoming')),
      200,
      scrollable: scrollableOf('settings.list'),
    );
    await tester.tap(find.byKey(const Key('settings.demoIncoming')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Входящий звонок'), findsOneWidget);
    expect(find.text('Азиз Каримов'), findsWidgets);

    await tester.tap(find.byKey(const Key('call.accept')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('история и контакты (демонстрация): фильтр пропущенных и поиск', (tester) async {
    await pumpApp(tester, saved: demoAccount);

    await tester.tap(find.byKey(const Key('tab.1')));
    await tester.pumpAndSettle();
    expect(find.text('Склад'), findsOneWidget);
    await tester.tap(find.text('Пропущенные'));
    await tester.pumpAndSettle();
    expect(find.text('Склад'), findsNothing);
    expect(find.text('Дилноза Юсупова'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contacts.search')), 'бух');
    await tester.pumpAndSettle();
    expect(find.text('Бухгалтерия'), findsOneWidget);
    expect(find.text('Азиз Каримов'), findsNothing);
    await tester.enterText(find.byKey(const Key('contacts.search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Никого не нашлось'), findsOneWidget);
  });

  testWidgets('настройки: стиль и язык меняются и запоминаются', (tester) async {
    await pumpApp(tester, saved: demoAccount);
    expect(styleOf(tester).id, SadoStyleId.emerald);

    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();

    for (final id in SadoStyleId.values) {
      final card = find.byKey(Key('style.${id.name}'));
      await tester.scrollUntilVisible(card, 80, scrollable: scrollableOf('settings.styles'));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(styleOf(tester).id, id, reason: 'стиль ${id.name} должен включиться');
      expect(tester.takeException(), isNull, reason: 'стиль ${id.name} рисуется без ошибок');
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('style'), SadoStyleId.values.last.name);

    // Язык выбирается из списка: нажимаем строку, затем вариант.
    await pick(tester, 'settings.language', 'English');
    expect(find.text('Language'), findsOneWidget);
    await pick(tester, 'settings.language', 'Oʻzbek');
    expect(find.text('Til'), findsOneWidget);
    expect(prefs.getString('lang'), 'uz');
  });

  testWidgets('все стили помещаются на маленьком телефоне в обеих темах', (tester) async {
    for (final id in SadoStyleId.values) {
      for (final mode in ['light', 'dark']) {
        await pumpApp(tester, saved: {...demoAccount, 'style': id.name, 'themeMode': mode}, size: const Size(320, 568));
        for (var tab = 0; tab < 4; tab++) {
          await tester.tap(find.byKey(Key('tab.$tab')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${id.name}/$mode, вкладка $tab');
        }
        // Экран разговора и клавиши донабора.
        await tester.tap(find.byKey(const Key('tab.0')));
        await tester.pumpAndSettle();
        await callAndAnswer(tester, '5');
        expect(tester.takeException(), isNull, reason: '${id.name}/$mode, экран разговора');
        await tester.tap(find.byKey(const Key('call.keypad')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${id.name}/$mode, клавиши донабора');
        await tester.tap(find.byKey(const Key('call.keypadClose')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('call.hangup')));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('клавиши в разговоре помещаются по ширине на обычном телефоне, «Назад» их закрывает', (tester) async {
    // Размер настоящего телефона, на котором нашлась ошибка: широкие клавиши «Материала» вылезали за края.
    const size = Size(394, 853);
    for (final id in SadoStyleId.values) {
      await pumpApp(tester, saved: {...demoAccount, 'style': id.name}, size: size);
      await tester.tap(find.byKey(Key('tab.${AppTab.dial.index}')));
      await tester.pumpAndSettle();
      await callAndAnswer(tester, '5');
      await tester.tap(find.byKey(const Key('call.keypad')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: id.name);
      expect(tester.getRect(find.byKey(const Key('dtmf.1'))).left, greaterThanOrEqualTo(0), reason: id.name);
      expect(tester.getRect(find.byKey(const Key('dtmf.3'))).right, lessThanOrEqualTo(size.width), reason: id.name);

      // Системная кнопка «Назад» закрывает клавиши, разговор продолжается.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const Key('call.keypadClose')), findsNothing, reason: id.name);
      expect(find.byKey(const Key('call.hangup')), findsOneWidget, reason: id.name);
      await tester.tap(find.byKey(const Key('call.hangup')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('кнопки «Принять» и «Отклонить» стоят внизу экрана, а не посередине', (tester) async {
    const size = Size(394, 853);
    await pumpApp(tester, saved: {...demoAccount, 'answerMode': 'buttons'}, size: size);
    await ringIn(tester);
    expect(tester.getCenter(find.byKey(const Key('call.accept'))).dy, greaterThan(size.height * 0.7));
    expect(tester.getCenter(find.byKey(const Key('call.decline'))).dy, greaterThan(size.height * 0.7));
  });

  testWidgets('ответ свайпом: вверх — разговор, вниз — отклонить, короткое движение не считается', (tester) async {
    await pumpApp(tester, saved: {...demoAccount, 'answerMode': 'swipe'});

    await ringIn(tester);
    expect(find.text('Вверх — ответить'), findsOneWidget);
    expect(find.text('Вниз — отклонить'), findsOneWidget);
    expect(find.byKey(const Key('call.accept')), findsNothing);

    // Короткое движение — случайное касание: звонок остаётся входящим.
    await tester.drag(find.byKey(const Key('answer.swipe')), const Offset(0, -25));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Входящий звонок'), findsOneWidget);

    await tester.drag(find.byKey(const Key('answer.swipe')), const Offset(0, -110));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();

    await ringIn(tester);
    await tester.drag(find.byKey(const Key('answer.swipe')), const Offset(0, 110));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Входящий звонок'), findsNothing);
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('ответ ползунком: довели до конца — разговор, не довели — нет; «Отклонить» отклоняет', (tester) async {
    await pumpApp(tester, saved: {...demoAccount, 'answerMode': 'slider'});

    await ringIn(tester);
    expect(find.text('Проведите, чтобы ответить'), findsOneWidget);

    await tester.drag(find.byKey(const Key('answer.slider')), const Offset(90, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Входящий звонок'), findsOneWidget);

    await tester.drag(find.byKey(const Key('answer.slider')), const Offset(330, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();

    await ringIn(tester);
    await tester.tap(find.byKey(const Key('call.decline')));
    await tester.pumpAndSettle();
    expect(find.text('Входящий звонок'), findsNothing);
  });

  testWidgets('настройки: набор значков и способ ответа меняются и запоминаются', (tester) async {
    await pumpApp(tester, saved: demoAccount);
    SadoIcons icons() => SadoIcons.of(tester.element(find.byType(Scaffold).first));
    expect(icons().id, IconSetId.outlined);

    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();

    await tester.scrollUntilVisible(find.text('Плотные'), 120, scrollable: scrollableOf('settings.list'));
    await tester.tap(find.text('Плотные'));
    await tester.pumpAndSettle();
    expect(icons().id, IconSetId.filled);
    expect(prefs.getString('iconSet'), 'filled');

    await tester.tap(find.text('Мягкие'));
    await tester.pumpAndSettle();
    expect(icons().id, IconSetId.rounded);

    await pick(tester, 'settings.answer', 'Ползунок вправо');
    expect(prefs.getString('answerMode'), 'slider');
    await pick(tester, 'settings.answer', 'Свайп в стороны');
    expect(prefs.getString('answerMode'), 'pill');
    await pick(tester, 'settings.answer', 'Свайп вверх-вниз');
    expect(prefs.getString('answerMode'), 'swipe');
  });

  testWidgets('входящий звонок помещается на маленьком телефоне во всех стилях и при любом способе ответа', (
    tester,
  ) async {
    for (final id in SadoStyleId.values) {
      for (final mode in ['buttons', 'swipe', 'slider', 'pill']) {
        await pumpApp(
          tester,
          saved: {...demoAccount, 'style': id.name, 'answerMode': mode},
          size: const Size(320, 568),
        );
        await ringIn(tester);
        expect(tester.takeException(), isNull, reason: '${id.name}, ответ: $mode');
        expect(find.text('Азиз Каримов'), findsWidgets);
        final container = ProviderScope.containerOf(tester.element(find.byType(SadoApp)));
        container.read(callProvider.notifier).hangUp();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
  });

  testWidgets('набор: кнопка вызова при пустом поле подставляет последний номер, второе нажатие звонит', (
    tester,
  ) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');
    // Раньше не звонили — подставлять нечего, кнопка ничего не делает.
    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('dialer.number'))).data, '');

    await callAndAnswer(tester, '1002');
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();
    // После вызова поле набора уже пустое — стирать нечего.
    expect(tester.widget<Text>(find.byKey(const Key('dialer.number'))).data, '');
    expect(tester.widget<Text>(find.byKey(const Key('dialer.number'))).data, '');

    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('dialer.number'))).data, '1002');
    expect(find.byKey(const Key('call.hangup')), findsNothing);

    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Вызов…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();
  });

  testWidgets('контакты: добавить, найти имя в истории и на звонке, изменить, удалить', (tester) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');

    // Сначала звоним на незнакомый номер — в истории он без имени.
    await callAndAnswer(tester, '1002');
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contacts.empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('contacts.add')));
    await tester.pumpAndSettle();
    // Пустую форму сохранить нельзя.
    await tester.tap(find.byKey(const Key('contact.save')));
    await tester.pumpAndSettle();
    expect(find.text('Заполните поле'), findsNWidgets(2));
    await tester.enterText(find.byKey(const Key('contact.name')), 'Азиз Каримов');
    await tester.enterText(find.byKey(const Key('contact.number')), '1002');
    await tester.tap(find.byKey(const Key('contact.save')));
    await tester.pumpAndSettle();
    expect(find.text('Азиз Каримов'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('contacts'), contains('"number":"1002"'));

    // В истории тот же номер теперь с именем.
    await tester.tap(find.byKey(const Key('tab.1')));
    await tester.pumpAndSettle();
    expect(find.text('Азиз Каримов'), findsOneWidget);

    // И на экране звонка — тоже.
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    await callAndAnswer(tester, '1002');
    expect(tester.widget<Text>(find.byKey(const Key('call.title'))).data, 'Азиз Каримов');
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();

    // Изменяем и удаляем через долгое нажатие.
    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Азиз Каримов'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact.edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact.name')), 'Азиз');
    await tester.tap(find.byKey(const Key('contact.save')));
    await tester.pumpAndSettle();
    expect(find.text('Азиз'), findsOneWidget);
    expect(find.text('Азиз Каримов'), findsNothing);

    await tester.longPress(find.text('Азиз'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact.delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contacts.empty')), findsOneWidget);
    expect(prefs.getString('contacts'), '[]');
  });

  testWidgets('перевод звонка: вводим номер — звонок переводится и завершается; до ответа кнопка неактивна', (
    tester,
  ) async {
    final engines = <_TransferSpy>[];
    await pumpApp(
      tester,
      saved: realAccount,
      savedPassword: 'secret',
      engine: (_) => (engines..add(_TransferSpy())).last,
    );

    for (final d in '1002'.split('')) {
      await tester.tap(find.byKey(Key('key.$d')));
    }
    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump(const Duration(milliseconds: 300));
    // Пока идёт вызов, переводить нечего.
    await tester.tap(find.byKey(const Key('call.transfer')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('transfer.number')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.tap(find.byKey(const Key('call.transfer')));
    // Два шага: первый запускает выезд окна, второй даёт ему доехать.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Номер набирается клавишами приложения: поля ввода (а значит и клавиатуры телефона) в окне нет.
    expect(find.byType(TextField), findsNothing);
    for (final d in '10055'.split('')) {
      await tester.tap(find.byKey(Key('transfer.key.$d')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('transfer.backspace')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('transfer.number'))).data, '1005');
    await tester.tap(find.byKey(const Key('transfer.submit')));
    await tester.pumpAndSettle();

    expect(engines.single.transferredTo, '1005');
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('«Не беспокоить»: входящий не показывается, звонящему — отказ, в истории пропущенный', (tester) async {
    final engines = <_TransferSpy>[];
    await pumpApp(
      tester,
      saved: {...realAccount, 'dnd': true},
      savedPassword: 'secret',
      engine: (_) => (engines..add(_TransferSpy())).last,
    );
    expect(find.text('1003 · не беспокоить'), findsOneWidget);
    expect(keeper.log.last, 'standby: 1003 · не беспокоить');

    await ringIn(tester);
    expect(find.text('Входящий звонок'), findsNothing);
    expect(engines.single.rejected, 1);
    expect(keeper.log.any((e) => e.startsWith('ring:')), isFalse);

    await tester.tap(find.byKey(const Key('tab.1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('пропущен'), findsOneWidget);

    // Выключаем — входящие снова показываются.
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.dnd')),
      120,
      scrollable: scrollableOf('settings.list'),
    );
    await tester.tap(find.descendant(of: find.byKey(const Key('settings.dnd')), matching: find.text('Выключено')));
    await tester.pumpAndSettle();
    await ringIn(tester);
    expect(find.text('Входящий звонок'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.decline')));
    await tester.pumpAndSettle();
  });

  testWidgets('входящий: «Без звука» глушит мелодию, звонок остаётся; свайп в стороны отвечает и отклоняет', (
    tester,
  ) async {
    await pumpApp(tester, saved: {...realAccount, 'answerMode': 'pill'}, savedPassword: 'secret');

    await ringIn(tester);
    expect(keeper.log.any((e) => e.endsWith('без звука')), isFalse);
    await tester.tap(find.byKey(const Key('call.silence')));
    await tester.pump();
    expect(keeper.log.where((e) => e.startsWith('ring:')).last, endsWith('без звука'));
    expect(find.text('Входящий звонок'), findsOneWidget);

    // Короткое движение не считается.
    await tester.drag(find.byKey(const Key('answer.pill')), const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Входящий звонок'), findsOneWidget);

    await tester.drag(find.byKey(const Key('answer.pill')), const Offset(140, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();

    await ringIn(tester);
    // У нового звонка мелодия снова включена.
    expect(keeper.log.where((e) => e.startsWith('ring:')).last.endsWith('без звука'), isFalse);
    await tester.drag(find.byKey(const Key('answer.pill')), const Offset(-140, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Входящий звонок'), findsNothing);
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('стили «Купертино» и «Материал»: буквы на клавишах и свой порядок вкладок', (tester) async {
    await pumpApp(tester, saved: {...demoAccount, 'style': 'cupertino', 'themeMode': 'light'});
    expect(find.text('ABC'), findsOneWidget);
    expect(find.text('WXYZ'), findsOneWidget);
    // Порядок стиля «Купертино»: недавние, контакты, клавиши.
    double x(int tab) => tester.getCenter(find.byKey(Key('tab.$tab'))).dx;
    expect(x(1) < x(2) && x(2) < x(0) && x(0) < x(3), isTrue);

    // В духе Material Design: внизу только «Главная» и «Клавиатура».
    await pumpApp(tester, saved: {...demoAccount, 'style': 'material', 'themeMode': 'light'});
    expect(find.text('ABC'), findsOneWidget);
    expect(x(1) < x(0), isTrue);
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Клавиатура'), findsOneWidget);
    expect(find.byKey(const Key('tab.2')), findsNothing);
    expect(find.byKey(const Key('tab.3')), findsNothing);

    await pumpApp(tester, saved: {...demoAccount, 'style': 'emerald'});
    expect(find.text('ABC'), findsNothing);
    expect(x(0) < x(1) && x(1) < x(2) && x(2) < x(3), isTrue);
  });

  testWidgets('«Материал»: главный экран с поиском и фильтрами, история по дням, настройки из меню', (tester) async {
    await pumpApp(tester, saved: {...demoAccount, 'style': 'material', 'themeMode': 'light'});
    await tester.tap(find.byKey(const Key('tab.1')));
    await tester.pumpAndSettle();
    // История разбита по дням, своего заголовка и переключателя у неё нет.
    expect(find.byKey(const Key('home.search')), findsOneWidget);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('История'), findsNothing);

    // Фильтр «Пропущенные» оставляет только пропущенные.
    final before = tester.widgetList(find.byType(Avatar)).length;
    await tester.tap(find.byKey(const Key('home.missed')));
    await tester.pumpAndSettle();
    expect(tester.widgetList(find.byType(Avatar)).length, lessThan(before));

    // «Контакты» — тоже фильтр; поиск в верхней строке ищет по контактам.
    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contacts.add')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('home.search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contacts.notFound')), findsOneWidget);

    // Настройки открываются значком меню в строке поиска; «Главная» возвращает назад.
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings.answer')), findsOneWidget);
    expect(find.byKey(const Key('home.search')), findsNothing);
    await tester.tap(find.byKey(const Key('tab.1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.search')), findsOneWidget);
  });

  testWidgets('«Материал»: в разговоре четыре кнопки, «Ещё» открывает удержание и перевод', (tester) async {
    await pumpApp(tester, saved: {...demoAccount, 'style': 'material'}, size: const Size(394, 853));
    await callAndAnswer(tester, '5');
    for (final key in ['call.keypad', 'call.mute', 'call.speaker', 'call.more', 'call.hangup']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.byKey(const Key('call.hold')), findsNothing);
    await tester.tap(find.byKey(const Key('call.more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('call.hold')), findsOneWidget);
    expect(find.byKey(const Key('call.transfer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('call.hangup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('способ ответа «как в стиле»: «Купертино» — ползунок, «Материал» — пилюля, остальные — кнопки', (
    tester,
  ) async {
    await pumpApp(tester, saved: {...demoAccount, 'style': 'cupertino'});
    await ringIn(tester);
    expect(find.byKey(const Key('answer.slider')), findsOneWidget);
    // В «Купертино» «Отклонить» и «Без звука» — маленькие круглые кнопки над ползунком.
    expect(find.byKey(const Key('call.decline')), findsOneWidget);
    expect(find.byKey(const Key('call.silence')), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.decline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('answer.slider')), findsNothing);

    await pumpApp(tester, saved: {...demoAccount, 'style': 'material'});
    await ringIn(tester);
    expect(find.byType(PillSwipeAnswer), findsOneWidget);

    await pumpApp(tester, saved: {...demoAccount, 'style': 'emerald'});
    await ringIn(tester);
    expect(find.byKey(const Key('call.accept')), findsOneWidget);
  });

  testWidgets('экран входа помещается на маленьком телефоне на всех языках', (tester) async {
    for (final lang in S.languageNames.keys) {
      await pumpApp(tester, saved: {'lang': lang}, size: const Size(320, 568));
      expect(tester.takeException(), isNull, reason: 'язык $lang');
      expect(find.byKey(const Key('login.demo')), findsOneWidget);
    }
  });
}

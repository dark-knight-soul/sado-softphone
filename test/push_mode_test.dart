// Режим «будить по звонку»: когда приложение уходит со связи, когда возвращается и что сообщает АТС.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/l10n/strings.dart';
import 'package:sado/platform/call_keeper.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/push_mode.dart';
import 'package:sado/state/session.dart';

import 'app_test.dart';

const _info = PushInfo(provider: 'fcm', project: 'my-pbx', token: 'device-token-1');

/// Чуть больше, чем приложение остаётся на связи после сворачивания, и запас на «прощание» с АТС.
const _afterLinger = Duration(seconds: 21);
const _afterWake = Duration(seconds: 41);
const _farewell = Duration(seconds: 2);

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(SadoApp)));

/// Запускает приложение с настоящей учётной записью; [push] — есть ли push на «телефоне», [mode] — выбран ли режим.
Future<DemoEngine> _start(
  WidgetTester tester, {
  PushInfo? push = _info,
  bool mode = true,
  bool wokenByPush = false,
  Map<String, Object> account = realAccount,
}) async {
  pushOnStart = push;
  wokenByPushOnStart = wokenByPush;
  addTearDown(() {
    pushOnStart = null;
    wokenByPushOnStart = false;
    _lifecycle(tester, AppLifecycleState.resumed);
  });
  // Приложение открыто и на экране (в тестах это нужно сказать явно).
  if (tester.binding.lifecycleState == null) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  } else {
    _lifecycle(tester, AppLifecycleState.resumed);
  }
  final engine = DemoEngine();
  await pumpApp(tester, saved: {...account, 'pushWake': mode}, savedPassword: 'secret', engine: (_) => engine);
  return engine;
}

/// Состояния окна по порядку: Flutter разрешает переходить только к соседнему.
const _ladder = [
  AppLifecycleState.resumed,
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];

/// Переводит окно в нужное состояние, проходя все промежуточные.
void _lifecycle(WidgetTester tester, AppLifecycleState target) {
  var at = _ladder.indexOf(tester.binding.lifecycleState ?? AppLifecycleState.resumed);
  if (at < 0) at = 0;
  final to = _ladder.indexOf(target);
  while (at != to) {
    at += at < to ? 1 : -1;
    tester.binding.handleAppLifecycleStateChanged(_ladder[at]);
  }
}

/// Приложение свернули.
Future<void> _hide(WidgetTester tester) async {
  _lifecycle(tester, AppLifecycleState.paused);
  await tester.pump();
}

/// Приложение снова открыли.
Future<void> _show(WidgetTester tester) async {
  _lifecycle(tester, AppLifecycleState.resumed);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Последнее, что приложение сказало телефону про фоновую службу: «standby», «hide» и т. п.
String _service() => keeper.log.lastWhere(
  (e) => e.startsWith('standby') || e == 'hide' || e.startsWith('ring') || e.startsWith('show'),
  orElse: () => '',
);

/// Движок, у которого подключение «идёт», но регистрации всё нет (сеть ещё не поднялась).
class _SlowEngine extends DemoEngine {
  @override
  Future<LinkStatus> connect(Account account, String password, {bool keepTrying = false, PushInfo? push}) async {
    connectedWith.add(push);
    link.value = LinkStatus.connecting;
    return LinkStatus.connecting;
  }
}

void main() {
  testWidgets('режим включён: на АТС уходят сведения о push; пока приложение на экране, оно на связи', (tester) async {
    final engine = await _start(tester);
    expect(engine.connectedWith, [_info]);
    await tester.pump(_afterLinger);
    await tester.pump(_farewell);
    expect(engine.sleeps, 0);
    expect(_container(tester).read(pushAsleepProvider), isFalse);
    expect(_service(), startsWith('standby'));
  });

  testWidgets('свернули — через 20 секунд приложение уходит со связи и убирает фоновую службу', (tester) async {
    final engine = await _start(tester);
    await _hide(tester);
    // Сразу не засыпает: человек мог просто переключиться в другое приложение.
    await tester.pump(const Duration(seconds: 10));
    expect(engine.sleeps, 0);
    expect(_service(), startsWith('standby'));

    await tester.pump(_afterLinger);
    expect(engine.sleeps, 1);
    await tester.pump(_farewell);
    expect(_container(tester).read(pushAsleepProvider), isTrue);
    expect(_service(), 'hide');
    expect(engine.link.value.isOnline, isFalse);
  });

  testWidgets('push будит: приложение выходит на связь, ждёт звонок 40 секунд и засыпает снова', (tester) async {
    final engine = await _start(tester);
    await _hide(tester);
    await tester.pump(_afterLinger);
    await tester.pump(_farewell);
    expect(_service(), 'hide');

    keeper.onPushWake!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.connectedWith, [_info, _info]);
    expect(engine.link.value.isOnline, isTrue);
    expect(_service(), startsWith('standby'));

    await tester.pump(const Duration(seconds: 30));
    expect(engine.sleeps, 1, reason: 'звонка ещё ждём');
    await tester.pump(_afterWake);
    await tester.pump(_farewell);
    expect(engine.sleeps, 2);
    expect(_service(), 'hide');
  });

  testWidgets('звонок после push держит приложение на связи; после разговора оно снова засыпает', (tester) async {
    final engine = await _start(tester);
    await _hide(tester);
    await tester.pump(_afterLinger);
    await tester.pump(_farewell);
    keeper.onPushWake!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    engine.simulateIncoming(number: '1002', name: 'Азиз Каримов');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_service(), startsWith('ring'));
    // Входящий звонит дольше, чем окно ожидания, — приложение не засыпает посреди звонка.
    await tester.pump(const Duration(seconds: 60));
    expect(engine.sleeps, 1);
    expect(engine.call.value?.phase, CallPhase.incoming);

    engine.hangUp();
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(engine.sleeps, 1, reason: 'после звонка ещё немного на связи');
    await tester.pump(_afterLinger);
    await tester.pump(_farewell);
    expect(engine.sleeps, 2);
    expect(_service(), 'hide');
  });

  testWidgets('приложение запущено push-уведомлением: ждёт звонок, а не засыпает через 20 секунд', (tester) async {
    final engine = await _start(tester, wokenByPush: true);
    await _hide(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(engine.sleeps, 0);
    await tester.pump(_afterWake);
    await tester.pump(_farewell);
    expect(engine.sleeps, 1);
  });

  testWidgets('открыли спящее приложение — оно сразу выходит на связь', (tester) async {
    final engine = await _start(tester);
    await _hide(tester);
    await tester.pump(_afterLinger);
    await tester.pump(_farewell);
    expect(engine.link.value.isOnline, isFalse);

    await _show(tester);
    expect(engine.connectedWith, [_info, _info]);
    expect(engine.link.value.isOnline, isTrue);
    expect(_container(tester).read(pushAsleepProvider), isFalse);
    expect(_service(), startsWith('standby'));
  });

  testWidgets('вернулись, пока приложение «прощалось» с АТС: оно остаётся на связи', (tester) async {
    final engine = await _start(tester);
    await _hide(tester);
    await tester.pump(_afterLinger);
    expect(engine.sleeps, 1);
    // Регистрация уже снята, но служба ещё не убрана — и тут человек открывает приложение.
    await _show(tester);
    await tester.pump(_farewell);
    expect(_container(tester).read(pushAsleepProvider), isFalse);
    expect(engine.link.value.isOnline, isTrue);
    expect(_service(), startsWith('standby'));
  });

  testWidgets('пока АТС не подтвердила регистрацию, приложение не засыпает (но и не ждёт вечно)', (tester) async {
    pushOnStart = _info;
    addTearDown(() {
      pushOnStart = null;
      _lifecycle(tester, AppLifecycleState.resumed);
    });
    if (tester.binding.lifecycleState == null) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    // Сеть ещё не поднялась: подключение идёт, но регистрации нет.
    final engine = _SlowEngine();
    await pumpApp(tester, saved: {...realAccount, 'pushWake': true}, savedPassword: 'secret', engine: (_) => engine);
    await _hide(tester);
    await tester.pump(const Duration(seconds: 60));
    expect(engine.sleeps, 0, reason: 'АТС ещё не знает адреса для push — уходить со связи рано');
    expect(_service(), startsWith('standby'));

    // Регистрация наконец прошла — теперь можно спать.
    engine.link.value = LinkStatus.online;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(_farewell);
    expect(engine.sleeps, 1);
    expect(_service(), 'hide');
  });

  testWidgets('сервер недоступен: через две минуты приложение всё же уходит со связи', (tester) async {
    pushOnStart = _info;
    addTearDown(() {
      pushOnStart = null;
      _lifecycle(tester, AppLifecycleState.resumed);
    });
    if (tester.binding.lifecycleState == null) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    final engine = _SlowEngine();
    await pumpApp(tester, saved: {...realAccount, 'pushWake': true}, savedPassword: 'secret', engine: (_) => engine);
    await _hide(tester);
    await tester.pump(const Duration(seconds: 100));
    expect(engine.sleeps, 0);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(_farewell);
    expect(engine.sleeps, 1);
  });

  testWidgets('адрес для push сменился во время разговора: АТС узнаёт его сразу после звонка', (tester) async {
    final engine = await _start(tester);
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    await callAndAnswer(tester, '1002');
    const fresh = PushInfo(provider: 'fcm', project: 'my-pbx', token: 'device-token-2');
    keeper.push = fresh;
    keeper.onPushTokenChanged!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.connectedWith, [_info], reason: 'во время разговора связь не трогаем');

    engine.hangUp();
    await tester.pumpAndSettle();
    expect(engine.connectedWith, [_info, fresh]);
    expect(engine.link.value.isOnline, isTrue);
  });

  testWidgets('телефон не сразу отдал сведения о push: приложение спрашивает снова', (tester) async {
    // Режим выбран, но сервисы Google ещё не ответили.
    final engine = await _start(tester, push: null);
    expect(engine.connectedWith, [null]);
    keeper.push = _info;
    await tester.pump(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_container(tester).read(pushInfoProvider), _info);
    expect(engine.connectedWith, [null, _info]);
  });

  testWidgets('режим выключен: приложение на связи постоянно и про push АТС не сообщает', (tester) async {
    final engine = await _start(tester, mode: false);
    expect(engine.connectedWith, [null]);
    await _hide(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(engine.sleeps, 0);
    expect(_service(), startsWith('standby'));
  });

  testWidgets('push на телефоне нет: режим не действует, даже если был выбран', (tester) async {
    final engine = await _start(tester, push: null);
    expect(engine.connectedWith, [null]);
    await _hide(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(engine.sleeps, 0);
    expect(_service(), startsWith('standby'));
  });

  testWidgets('демонстрационная учётная запись: режим не действует', (tester) async {
    final engine = await _start(tester, account: demoAccount);
    expect(engine.connectedWith, [null]);
    await _hide(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(engine.sleeps, 0);
  });

  testWidgets('переключатель в настройках виден, только если push на телефоне есть', (tester) async {
    await _start(tester, push: null, mode: false);
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.background')),
      120,
      scrollable: scrollableOf('settings.list'),
    );
    expect(find.byKey(const Key('settings.pushWake')), findsNothing);
  });

  testWidgets('включили режим в настройках — АТС сразу получает сведения о push; выключили — забывает', (tester) async {
    final engine = await _start(tester, mode: false);
    expect(engine.connectedWith, [null]);
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('settings.pushWake'));
    await tester.scrollUntilVisible(toggle, 120, scrollable: scrollableOf('settings.list'));
    await Scrollable.ensureVisible(tester.element(toggle), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(find.text('Будить по звонку (пробный режим)'), findsOneWidget);

    await tester.tap(find.descendant(of: toggle, matching: find.text('Включено')));
    await tester.pumpAndSettle();
    expect(engine.connectedWith, [null, _info]);
    expect(engine.link.value.isOnline, isTrue);

    await tester.tap(find.descendant(of: toggle, matching: find.text('Выключено')));
    await tester.pumpAndSettle();
    // Обычная регистрация без сведений о push — знак для АТС, что будить этот телефон больше не надо.
    expect(engine.connectedWith, [null, _info, null]);
    expect(engine.link.value.isOnline, isTrue);
  });

  testWidgets('строка режима в настройках помещается на маленьком телефоне на каждом языке', (tester) async {
    // Настройки смотрят в открытом приложении: говорим тесту, что окно на экране.
    if (tester.binding.lifecycleState == null) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    } else {
      _lifecycle(tester, AppLifecycleState.resumed);
    }
    for (final lang in S.languageNames.keys) {
      pushOnStart = _info;
      addTearDown(() => pushOnStart = null);
      await pumpApp(
        tester,
        saved: {...realAccount, 'lang': lang, 'pushWake': true},
        savedPassword: 'secret',
        size: const Size(320, 568),
      );
      await tester.tap(find.byKey(const Key('tab.3')));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('settings.pushWake'));
      await tester.scrollUntilVisible(toggle, 120, scrollable: scrollableOf('settings.list'));
      await Scrollable.ensureVisible(tester.element(toggle), alignment: 0.3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'язык $lang');
      expect(find.text(S.byCode(lang).pushWake), findsOneWidget, reason: 'язык $lang');
      expect(find.text(S.byCode(lang).pushWakeNote), findsOneWidget, reason: 'язык $lang');
    }
  });

  testWidgets('адрес телефона для push сменился — АТС узнаёт новый', (tester) async {
    final engine = await _start(tester);
    const fresh = PushInfo(provider: 'fcm', project: 'my-pbx', token: 'device-token-2');
    keeper.push = fresh;
    keeper.onPushTokenChanged!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.connectedWith, [_info, fresh]);
  });

  testWidgets('выход из учётной записи: перед уходом АТС сообщают, что будить телефон не нужно', (tester) async {
    final engine = await _start(tester);
    await _container(tester).read(sessionProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(engine.connectedWith, [_info, null]);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
  });

  testWidgets('во время разговора режим не переключает связь', (tester) async {
    final engine = await _start(tester, mode: false);
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    await callAndAnswer(tester, '1002');
    _container(tester).read(sessionProvider.notifier).usePush(_info);
    await tester.pump();
    expect(engine.sleeps, 0);
    expect(engine.connectedWith, [null]);
    expect(engine.call.value?.phase, CallPhase.active);
  });
}

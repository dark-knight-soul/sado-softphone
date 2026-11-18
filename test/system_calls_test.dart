// Пробный режим «Системные звонки»: что приложение сообщает системе звонков телефона и как выполняет её команды.
// Телефон здесь учебный (RecordingKeeper): проверяется порядок сообщений, а не сама система Android.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/platform/call_keeper.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/settings.dart';
import 'package:sado/state/system_calls.dart';

import 'app_test.dart';

const _on = <String, Object>{...realAccount, 'systemCalls': true};

/// Запускает приложение с обычной учётной записью (звонки ведёт имитация) и открывает набор номера.
Future<DemoEngine> _start(WidgetTester tester, {Map<String, Object> saved = _on}) async {
  final engine = DemoEngine();
  await pumpApp(tester, saved: saved, savedPassword: 'secret', engine: (_) => engine);
  await tester.tap(find.byKey(const Key('tab.0')));
  await tester.pumpAndSettle();
  return engine;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('режим выключен — системе ничего не сообщаем', (tester) async {
    final engine = await _start(tester, saved: realAccount);
    await callAndAnswer(tester, '1002');
    engine.hangUp();
    await tester.pumpAndSettle();
    expect(keeper.system, isEmpty);
  });

  testWidgets('демонстрация — системе ничего не сообщаем, даже если режим включён', (tester) async {
    await _start(tester, saved: {...demoAccount, 'systemCalls': true});
    await callAndAnswer(tester, '1002');
    expect(keeper.system, isEmpty);
  });

  testWidgets('исходящий: начало, соединение, удержание, снятие, конец', (tester) async {
    final engine = await _start(tester);
    for (final d in '1002'.split('')) {
      await tester.tap(find.byKey(Key('key.$d')));
    }
    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump(const Duration(milliseconds: 300));
    final id = engine.call.value!.id;
    expect(keeper.system, ['start $id 1002 outgoing'], reason: 'пока идёт вызов, о соединении не сообщаем');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(keeper.system.last, 'active $id');

    engine.setHeld(true);
    await _settle(tester);
    expect(keeper.system.last, 'held $id');
    engine.setHeld(false);
    await _settle(tester);
    expect(keeper.system.last, 'active $id');

    engine.hangUp();
    await tester.pumpAndSettle();
    expect(keeper.system, ['start $id 1002 outgoing', 'active $id', 'held $id', 'active $id', 'end $id local']);
  });

  testWidgets('входящий, на который не ответили, — «пропущен»', (tester) async {
    final engine = await _start(tester);
    engine.simulateIncoming(number: '1005', name: 'Склад');
    await _settle(tester);
    final id = engine.call.value!.id;
    expect(keeper.system, ['start $id 1005 incoming']);
    engine.hangUp();
    await tester.pumpAndSettle();
    expect(keeper.system.last, 'end $id missed');
  });

  testWidgets('команды системы: ответить, удержать, снять с удержания, завершить', (tester) async {
    final engine = await _start(tester);
    engine.simulateIncoming(number: '1005', name: 'Склад');
    await _settle(tester);
    final id = engine.call.value!.id;

    keeper.onSystemCall!(id, SystemCallAction.answer);
    await _settle(tester);
    expect(engine.call.value!.phase, CallPhase.active, reason: 'кнопка гарнитуры отвечает на звонок');
    expect(keeper.system.last, 'active $id');

    keeper.onSystemCall!(id, SystemCallAction.hold);
    await _settle(tester);
    expect(engine.call.value!.held, isTrue, reason: 'пришёл сотовый звонок — наш разговор на удержании');
    keeper.onSystemCall!(id, SystemCallAction.unhold);
    await _settle(tester);
    expect(engine.call.value!.held, isFalse);

    keeper.onSystemCall!(id, SystemCallAction.hangUp);
    await tester.pumpAndSettle();
    expect(engine.call.value, isNull);
    expect(keeper.system.last, 'end $id local');
  });

  testWidgets('команда для чужого или уже законченного звонка ничего не ломает', (tester) async {
    final engine = await _start(tester);
    await callAndAnswer(tester, '1002');
    final id = engine.call.value!.id;
    for (final action in SystemCallAction.values) {
      keeper.onSystemCall!(id + 100, action);
    }
    await _settle(tester);
    expect(engine.call.value!.phase, CallPhase.active);
    expect(engine.call.value!.held, isFalse);
    // «Ответить» на уже соединённый звонок — тоже ничего.
    keeper.onSystemCall!(id, SystemCallAction.answer);
    await _settle(tester);
    expect(engine.call.value!.phase, CallPhase.active);
  });

  testWidgets('два разговора: переключение не выглядит для системы как конец звонка', (tester) async {
    final engine = await _start(tester);
    await callAndAnswer(tester, '1002');
    final first = engine.call.value!.id;
    engine.simulateIncoming(number: '1005', name: 'Склад');
    await _settle(tester);
    final second = engine.other.value!.id;
    expect(keeper.system.last, 'start $second 1005 incoming');

    // Система просит ответить на второй (кнопка гарнитуры): первый уходит на удержание.
    keeper.onSystemCall!(second, SystemCallAction.answer);
    await _settle(tester);
    expect(engine.call.value!.id, second);
    expect(keeper.system, containsAll(['held $first', 'active $second']));

    keeper.system.clear();
    engine.swap();
    await _settle(tester);
    expect(keeper.system, unorderedEquals(['active $first', 'held $second']));
    expect(keeper.system.where((line) => line.startsWith('end')), isEmpty);

    // Система просит вернуть удержанный разговор — это то же переключение.
    keeper.system.clear();
    keeper.onSystemCall!(second, SystemCallAction.unhold);
    await _settle(tester);
    expect(engine.call.value!.id, second);
    expect(keeper.system, unorderedEquals(['held $first', 'active $second']));
  });

  testWidgets('режим включили посреди разговора — система узнаёт о нём сразу; выключили — доводим до конца', (
    tester,
  ) async {
    systemCallsOnStart = true;
    addTearDown(() => systemCallsOnStart = false);
    final engine = await _start(tester, saved: realAccount);
    await callAndAnswer(tester, '1002');
    final id = engine.call.value!.id;
    expect(keeper.system, isEmpty);

    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    container.read(settingsProvider.notifier).setSystemCalls(true);
    await _settle(tester);
    expect(keeper.system, ['start $id 1002 outgoing', 'active $id']);

    container.read(settingsProvider.notifier).setSystemCalls(false);
    await _settle(tester);
    engine.hangUp();
    await tester.pumpAndSettle();
    expect(keeper.system.last, 'end $id local');
  });

  testWidgets('переключатель в настройках виден, только если телефон это умеет', (tester) async {
    await _start(tester, saved: realAccount);
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings.systemCalls'), skipOffstage: false), findsNothing);

    systemCallsOnStart = true;
    addTearDown(() => systemCallsOnStart = false);
    await _start(tester, saved: realAccount);
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('settings.systemCalls'));
    await tester.scrollUntilVisible(row, 120, scrollable: scrollableOf('settings.list'));
    await tester.tap(find.descendant(of: row, matching: find.text('Включено')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    expect(container.read(settingsProvider).systemCalls, isTrue);
    expect(container.read(prefsProvider).getBool('systemCalls'), isTrue);
  });

  test('устройства звука от системы: список, выбранное, выбор человека уходит системе', () {
    final keeper = RecordingKeeper();
    final audio = SystemAudio(keeper);
    var changes = 0;
    audio.addListener(() => changes++);
    expect(audio.routes, isNull, reason: 'пока система молчит, звук переключает сам движок');

    audio.update(7, const [], null);
    expect(audio.routes, isNull, reason: 'пустой список — система ещё не разобралась');
    expect(changes, 0);

    const list = [
      AudioRoute(AudioKind.earpiece),
      AudioRoute(AudioKind.speaker),
      AudioRoute(AudioKind.bluetooth, 'Buds'),
    ];
    audio.update(7, list, AudioKind.bluetooth);
    expect(audio.routes, list);
    expect(audio.current, AudioKind.bluetooth);
    expect(changes, 1);

    audio.select(AudioKind.speaker);
    expect(keeper.system, ['route 7 speaker']);

    // Второй звонок: выбор уходит тому, о ком система говорила последним.
    audio.update(8, list, AudioKind.speaker);
    audio.select(AudioKind.earpiece);
    expect(keeper.system.last, 'route 8 earpiece');
    audio.forget(8);
    expect(audio.current, AudioKind.bluetooth, reason: 'остался первый звонок');
    audio.forget(7);
    expect(audio.routes, isNull);
    audio.forget(7);
    expect(changes, 4, reason: 'повторное «забудь» ничего не меняет');
    audio.select(AudioKind.speaker);
    expect(keeper.system.length, 2, reason: 'без звонков выбор никуда не уходит');
  });

  testWidgets('сообщения телефона разбираются: команды, устройства звука, «звонок больше не ведётся»', (tester) async {
    final android = AndroidCallKeeper();
    final commands = <String>[];
    final routes = <String>[];
    final gone = <int>[];
    android.onSystemCall = (id, action) => commands.add('$id ${action.name}');
    android.onSystemRoutes = (id, list, current) => routes.add('$id $list ${current?.name}');
    android.onSystemCallGone = gone.add;

    Future<void> fromPhone(String method, Object? arguments) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'uz.sado.app/call',
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
          (_) {},
        );

    await fromPhone('systemCall', {'id': 3, 'action': 'answer'});
    await fromPhone('systemCall', {'id': 3, 'action': 'unhold'});
    await fromPhone('systemCall', {'id': 3, 'action': 'fly'});
    await fromPhone('systemCall', {'action': 'hangUp'});
    await fromPhone('systemCall', 'мусор');
    expect(commands, ['3 answer', '3 unhold']);

    await fromPhone('systemRoutes', {
      'id': 3,
      'routes': [
        {'kind': 'speaker', 'name': 'Speaker'},
        {'kind': 'bluetooth', 'name': 'Buds'},
        {'kind': 'bluetooth', 'name': 'Car'},
        {'kind': 'earpiece', 'name': 'Earpiece'},
        {'kind': 'teleport', 'name': '?'},
        'мусор',
      ],
      'current': 'bluetooth',
    });
    await fromPhone('systemRoutes', {'id': 4, 'routes': null, 'current': null});
    expect(routes, [
      '3 [AudioRoute(earpiece), AudioRoute(speaker), AudioRoute(bluetooth, Buds)] bluetooth',
      '4 [] null',
    ]);

    await fromPhone('systemCallGone', 3);
    await fromPhone('systemCallGone', 'три');
    expect(gone, [3]);
  });
}

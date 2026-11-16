// Второй звонок: ожидание ответа во время разговора, ответ с удержанием первого, переключение,
// завершение одного из двух, ограничения («занято»), «Не беспокоить», история и раскладка на маленьком экране.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/data/demo_data.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/call.dart';
import 'package:sado/state/history.dart';
import 'package:sado/theme/sado_style.dart';

import 'app_test.dart';

/// Имитация, которая запоминает, как отклоняли второй звонок («занято» или «отклонено»).
class _RejectSpy extends DemoEngine {
  final rejectedOther = <bool>[];

  @override
  void rejectOther({bool busy = false}) {
    rejectedOther.add(busy);
    super.rejectOther(busy: busy);
  }
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(SadoApp)));

/// Звонок наружу на 1002, имитация отвечает — идёт первый разговор.
Future<void> _talk(WidgetTester tester) async {
  await tester.tap(find.byKey(Key('tab.${AppTab.dial.index}')));
  await tester.pumpAndSettle();
  await callAndAnswer(tester, '1002');
}

/// Во время разговора звонит второй.
Future<void> _ringSecond(
  WidgetTester tester,
  DemoEngine engine, {
  String number = '1005',
  String? name = 'Склад',
}) async {
  engine.simulateIncoming(number: number, name: name);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

String _title(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('call.title'))).data!;

/// Подпись под именем: таймер «мм:сс» или «На удержании».
String _status(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byKey(const Key('call.status')), matching: find.byType(Text))).data!;

final _timer = RegExp(r'^\d\d:\d\d$');

List<String> _missedLog() => keeper.log.where((e) => e.startsWith('missed:')).toList();

void main() {
  group('DemoEngine: два звонка', () {
    late DemoEngine engine;

    setUp(() => engine = DemoEngine(answerAfter: Duration.zero));
    tearDown(() => engine.dispose());

    Future<void> talk() async {
      engine.dial('1002');
      await Future<void>.delayed(Duration.zero);
      expect(engine.call.value?.phase, CallPhase.active);
    }

    test('второй входящий во время разговора ждёт ответа, первый не трогается', () async {
      await talk();
      final first = engine.call.value!;
      engine.simulateIncoming(number: '1005');
      expect(engine.call.value, first);
      expect(engine.other.value?.phase, CallPhase.incoming);
      expect(engine.other.value?.number, '1005');
      expect(engine.other.value?.id, isNot(first.id));
    });

    test('ответ: первый на удержании, второй — текущий и активный, звук там же; переключение и завершение', () async {
      await talk();
      engine.setSpeaker(true);
      final first = engine.call.value!;
      engine.simulateIncoming(number: '1005');
      final second = engine.other.value!;

      engine.acceptOther();
      expect(engine.call.value?.id, second.id);
      expect(engine.call.value?.phase, CallPhase.active);
      expect(engine.call.value?.held, isFalse);
      expect(engine.call.value?.speaker, isTrue);
      expect(engine.other.value?.id, first.id);
      expect(engine.other.value?.held, isTrue);

      engine.swap();
      expect(engine.call.value?.id, first.id);
      expect(engine.call.value?.held, isFalse);
      expect(engine.other.value?.id, second.id);
      expect(engine.other.value?.held, isTrue);

      // Текущий завершён — удержанный становится текущим и снимается с удержания, звук остаётся там же.
      engine.hangUp();
      expect(engine.call.value?.id, second.id);
      expect(engine.call.value?.held, isFalse);
      expect(engine.call.value?.speaker, isTrue);
      expect(engine.other.value, isNull);

      engine.hangUp();
      expect(engine.call.value, isNull);
    });

    test('отклонить второй: текущий не меняется; ожидающий сам положил трубку — тоже', () async {
      await talk();
      final first = engine.call.value!;
      engine.simulateIncoming(number: '1005');
      engine.rejectOther();
      expect(engine.other.value, isNull);
      expect(engine.call.value, first);

      engine.simulateIncoming(number: '1006');
      engine.otherHangsUp();
      expect(engine.other.value, isNull);
      expect(engine.call.value, first);
    });

    test('«занято»: третий звонок, второй во время вызова и во время непринятого входящего', () async {
      engine = DemoEngine(answerAfter: const Duration(hours: 1));
      engine.dial('1002');
      engine.simulateIncoming(number: '1005');
      expect(engine.busyRejected, 1);
      expect(engine.other.value, isNull);
      engine.hangUp();

      engine.simulateIncoming(number: '1002');
      engine.simulateIncoming(number: '1005');
      expect(engine.busyRejected, 2);
      expect(engine.other.value, isNull);
      expect(engine.call.value?.number, '1002');

      engine.accept();
      engine.simulateIncoming(number: '1005');
      engine.acceptOther();
      final call = engine.call.value;
      final other = engine.other.value;
      engine.simulateIncoming(number: '1007');
      expect(engine.busyRejected, 3);
      expect(engine.call.value, call);
      expect(engine.other.value, other);
    });

    test('текущий кончился, пока второй ещё звонит: второй звонит как обычный входящий', () async {
      await talk();
      engine.simulateIncoming(number: '1005');
      engine.hangUp();
      expect(engine.call.value?.phase, CallPhase.incoming);
      expect(engine.call.value?.number, '1005');
      expect(engine.other.value, isNull);
    });
  });

  testWidgets('второй входящий во время разговора: карточка, экран и таймер первого остаются', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _talk(tester);
    final ringsBefore = keeper.log.where((e) => e.startsWith('ring:')).length;
    // Клавиши набора тоже щёлкают вибрацией — считаем только то, что после начала разговора.
    haptics.clear();

    await _ringSecond(tester, engine);
    expect(find.byKey(const Key('call.waiting')), findsOneWidget);
    expect(find.text('Второй звонок'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    expect(find.byKey(const Key('call.waiting.accept')), findsOneWidget);
    expect(find.byKey(const Key('call.waiting.decline')), findsOneWidget);
    // Экран разговора не сменился на экран входящего, мелодии нет, вибрация — один короткий отклик.
    expect(find.byKey(const Key('call.accept')), findsNothing);
    expect(_title(tester), '1002');
    expect(_status(tester), matches(_timer));
    expect(keeper.log.where((e) => e.startsWith('ring:')).length, ringsBefore);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);

    await tester.pump(const Duration(seconds: 2));
    expect(_status(tester), matches(_timer));
    expect(haptics, hasLength(1));
  });

  testWidgets('ответ на второй, переключение, завершение текущего — удержанный возвращается', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    final standbys = keeper.log.where((e) => e.startsWith('standby:')).length;
    await _ringSecond(tester, engine);

    await _tap(tester, 'call.waiting.accept');
    expect(find.byKey(const Key('call.waiting')), findsNothing);
    expect(_title(tester), 'Склад');
    expect(_status(tester), matches(_timer));
    expect(engine.call.value?.phase, CallPhase.active);
    expect(engine.other.value?.held, isTrue);
    expect(find.byKey(const Key('call.other')), findsOneWidget);
    expect(find.text('На удержании: 1002'), findsOneWidget);
    // Уведомление описывает текущий разговор.
    expect(keeper.log.last, contains('Склад'));

    await _tap(tester, 'call.swap');
    expect(_title(tester), '1002');
    expect(engine.call.value?.held, isFalse);
    expect(engine.other.value?.number, '1005');
    expect(engine.other.value?.held, isTrue);
    expect(find.text('На удержании: Склад'), findsOneWidget);

    // Кнопки действуют на текущий звонок.
    await _tap(tester, 'call.speaker');
    expect(engine.call.value?.speaker, isTrue);
    expect(engine.other.value?.speaker, isFalse);

    await _tap(tester, 'call.hangup');
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);
    expect(find.byKey(const Key('call.other')), findsNothing);
    expect(_title(tester), 'Склад');
    expect(engine.call.value?.held, isFalse);
    expect(_status(tester), matches(_timer));
    // Звук остался там, куда его вывел человек.
    expect(engine.call.value?.speaker, isTrue);
    // Служба в шторке не останавливалась, пока звонки менялись.
    expect(keeper.log.where((e) => e.startsWith('standby:')).length, standbys);
    expect(keeper.log.contains('lock: false'), isFalse);

    await _tap(tester, 'call.hangup');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('«Отклонить» второй: карточка уходит, первый идёт, в истории пропущенный без уведомления', (
    tester,
  ) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    final first = engine.call.value;
    await _ringSecond(tester, engine);

    await _tap(tester, 'call.waiting.decline');
    expect(find.byKey(const Key('call.waiting')), findsNothing);
    expect(engine.call.value, first);
    expect(_title(tester), '1002');
    expect(_status(tester), matches(_timer));
    final history = _container(tester).read(historyProvider);
    expect(history.first.number, '1005');
    expect(history.first.kind, CallKind.missed);
    expect(_missedLog(), isEmpty);
  });

  testWidgets('ожидающий не дождался: карточка уходит, пропущенный и уведомление', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _ringSecond(tester, engine);

    engine.otherHangsUp();
    await tester.pump();
    expect(find.byKey(const Key('call.waiting')), findsNothing);
    expect(_title(tester), '1002');
    final history = _container(tester).read(historyProvider);
    expect(history.single.kind, CallKind.missed);
    expect(history.single.name, 'Склад');
    expect(_missedLog(), ['missed: Пропущенный звонок | Склад']);
  });

  testWidgets('удержанный положил трубку: строка «На удержании» уходит, текущий не меняется', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _ringSecond(tester, engine);
    await _tap(tester, 'call.waiting.accept');
    final current = engine.call.value;

    engine.otherHangsUp();
    await tester.pump();
    expect(find.byKey(const Key('call.other')), findsNothing);
    expect(engine.call.value, current);
    expect(_title(tester), 'Склад');
    // Первый разговор записан в историю как исходящий.
    expect(_container(tester).read(historyProvider).single.kind, CallKind.outgoing);
  });

  testWidgets('третий звонок получает «занято» и не мешает двум', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _ringSecond(tester, engine);

    // Пока второй ещё звонит.
    await _ringSecond(tester, engine, number: '1007', name: 'Охрана');
    expect(engine.busyRejected, 1);
    expect(find.text('Охрана'), findsNothing);
    expect(find.text('Склад'), findsOneWidget);

    // И когда идут два разговора.
    await _tap(tester, 'call.waiting.accept');
    await _ringSecond(tester, engine, number: '1007', name: 'Охрана');
    expect(engine.busyRejected, 2);
    expect(find.text('Охрана'), findsNothing);
    expect(_title(tester), 'Склад');
    expect(find.text('На удержании: 1002'), findsOneWidget);
    expect(find.byKey(const Key('call.waiting')), findsNothing);
    // Отклонённые «занято» третьи звонки в историю не попадают: их не было ни на экране, ни в движке.
    expect(_container(tester).read(historyProvider), isEmpty);
  });

  testWidgets('второй входящий, пока первый ещё звонит или идёт вызов, — «занято»', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);

    await ringIn(tester);
    await _ringSecond(tester, engine);
    expect(engine.busyRejected, 1);
    expect(engine.other.value, isNull);
    expect(find.byKey(const Key('call.accept')), findsOneWidget);
    expect(_title(tester), 'Азиз Каримов');
    await tester.tap(find.byKey(const Key('call.decline')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('tab.${AppTab.dial.index}')));
    await tester.pumpAndSettle();
    for (final d in '1002'.split('')) {
      await tester.tap(find.byKey(Key('key.$d')));
    }
    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(engine.call.value?.phase, CallPhase.outgoing);
    await _ringSecond(tester, engine);
    expect(engine.busyRejected, 2);
    expect(engine.other.value, isNull);
    expect(find.byKey(const Key('call.waiting')), findsNothing);
    await _tap(tester, 'call.hangup');
    await tester.pumpAndSettle();
  });

  testWidgets('«Не беспокоить»: второй входящий отклоняется «занято» и записывается пропущенным', (tester) async {
    final engine = _RejectSpy();
    await pumpApp(tester, saved: {...realAccount, 'dnd': true}, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    expect(_title(tester), '1002');

    await _ringSecond(tester, engine);
    expect(engine.rejectedOther, [true]);
    expect(engine.other.value, isNull);
    expect(find.byKey(const Key('call.waiting')), findsNothing);
    expect(_title(tester), '1002');
    final history = _container(tester).read(historyProvider);
    expect(history.single.kind, CallKind.missed);
    expect(history.single.number, '1005');
    // Как и у первого звонка при «Не беспокоить»: уведомление о пропущенном есть.
    expect(_missedLog(), ['missed: Пропущенный звонок | Склад']);
  });

  // Длительность здесь не проверяем: таймер разговора считает по настоящим часам, а тест «перематывает» только свои.
  testWidgets('история после двух разговоров: две записи, у каждой свой вид', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _ringSecond(tester, engine);
    await _tap(tester, 'call.waiting.accept');
    await _tap(tester, 'call.hangup');
    var history = _container(tester).read(historyProvider);
    expect(history, hasLength(1));
    expect(history.single.kind, CallKind.incoming);
    expect(history.single.name, 'Склад');

    await tester.pump(const Duration(seconds: 2));
    await _tap(tester, 'call.hangup');
    await tester.pumpAndSettle();
    history = _container(tester).read(historyProvider);
    expect(history, hasLength(2));
    expect(history.first.kind, CallKind.outgoing);
    expect(history.first.number, '1002');
    expect(history.last.kind, CallKind.incoming);
  });

  testWidgets('карточка и строка второго звонка помещаются на коротком экране во всех стилях', (tester) async {
    for (final (id, inset) in [
      for (final id in SadoStyleId.values) ...[(id, false), (id, true)],
    ]) {
      final engine = DemoEngine();
      await pumpApp(
        tester,
        saved: {...demoAccount, 'style': id.name},
        size: const Size(320, 568),
        engine: (_) => engine,
      );
      // Строка состояния сверху и три кнопки навигации снизу — как на недорогом телефоне; и без них.
      tester.view.padding = inset ? const FakeViewPadding(top: 24, bottom: 48) : FakeViewPadding.zero;
      tester.view.viewPadding = inset ? const FakeViewPadding(top: 24, bottom: 48) : FakeViewPadding.zero;
      final top = inset ? 24.0 : 0.0;
      final bottom = inset ? 568 - 48 : 568.0;
      final name = '${id.name}${inset ? ' с полосами' : ''}';
      await tester.pumpAndSettle();
      await _talk(tester);
      // Длинное имя второго звонящего — самый тяжёлый случай для строки.
      await _ringSecond(tester, engine, name: 'Отдел снабжения и логистики, склад №2');

      Future<void> check(String what, String key) async {
        expect(tester.takeException(), isNull, reason: '$name: $what');
        final hangup = tester.getRect(find.byKey(const Key('call.hangup')));
        expect(hangup.bottom, lessThanOrEqualTo(bottom), reason: '$name: $what — «Завершить» над полосой');
        final bar = tester.getRect(find.byKey(Key(key)));
        expect(bar.top, greaterThanOrEqualTo(top), reason: '$name: $what');
        expect(bar.right, lessThanOrEqualTo(320), reason: '$name: $what');
        expect(bar.bottom, lessThanOrEqualTo(hangup.top), reason: '$name: $what');
      }

      await check('карточка', 'call.waiting');
      await _tap(tester, 'call.keypad');
      await check('карточка и клавиши', 'call.waiting');
      await _tap(tester, 'call.keypadClose');

      await _tap(tester, 'call.waiting.accept');
      await check('строка удержания', 'call.other');
      await _tap(tester, 'call.keypad');
      await check('строка удержания и клавиши', 'call.other');
      await _tap(tester, 'call.keypadClose');

      // Завершаем без нажатий: экран с одним звонком на этом размере проверяет app_test.dart.
      engine.hangUp();
      expect(engine.call.value?.number, '1002', reason: name);
      engine.hangUp();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('call.hangup')), findsNothing, reason: name);
    }
  });

  testWidgets('один звонок на коротком экране с полосами системы: «Завершить» над нижней панелью', (tester) async {
    for (final id in SadoStyleId.values) {
      await pumpApp(tester, saved: {...demoAccount, 'style': id.name}, size: const Size(320, 568));
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('tab.${AppTab.dial.index}')));
      await tester.pumpAndSettle();
      // Сохранённый контакт: под именем ещё строка с номером — самая высокая шапка.
      await callAndAnswer(tester, '1002');
      expect(tester.takeException(), isNull, reason: id.name);
      final hangup = tester.getRect(find.byKey(const Key('call.hangup')));
      expect(hangup.bottom, lessThanOrEqualTo(568 - 48), reason: id.name);
      await tester.tap(find.byKey(const Key('call.hangup')));
      await tester.pumpAndSettle();
    }
  });
}

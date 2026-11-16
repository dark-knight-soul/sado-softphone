// Перевод с консультацией: «Сначала поговорить» в окне перевода (первый звонок — на удержание, второй — исходящий),
// «Соединить» на строке удержания, возврат удержанного при неудаче, отказ АТС, ограничения и раскладка на маленьком экране.
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

/// Имитация, которая запоминает слепые переводы (как в app_test.dart).
class _BlindSpy extends DemoEngine {
  String? transferredTo;

  @override
  void transfer(String target) {
    transferredTo = target;
    super.transfer(target);
  }
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(SadoApp)));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Звонок наружу на 1002, имитация отвечает — идёт первый разговор.
Future<void> _talk(WidgetTester tester) async {
  await tester.tap(find.byKey(Key('tab.${AppTab.dial.index}')));
  await tester.pumpAndSettle();
  await callAndAnswer(tester, '1002');
}

/// Открывает окно перевода (в стиле «Материал» кнопка спрятана под «Ещё») и набирает номер.
Future<void> _openTransfer(WidgetTester tester, String number) async {
  if (find.byKey(const Key('call.transfer')).hitTestable().evaluate().isEmpty) {
    await _tap(tester, 'call.more');
  }
  await tester.tap(find.byKey(const Key('call.transfer')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  for (final d in number.split('')) {
    await tester.tap(find.byKey(Key('transfer.key.$d')));
  }
  await tester.pump();
}

/// «Сначала поговорить» с [number]: окно закрывается, начинается второй вызов.
Future<void> _consult(WidgetTester tester, String number) async {
  await _openTransfer(tester, number);
  await tester.tap(find.byKey(const Key('transfer.consult')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Дождаться, пока имитация ответит на вызов «Сначала поговорить».
Future<void> _answered(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
}

String _title(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('call.title'))).data!;

/// Подпись под именем: «Вызов…», таймер «мм:сс» или «На удержании» (у вызова ключ стоит на самом тексте).
String _status(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(const Key('call.status')), matching: find.byType(Text), matchRoot: true),
    )
    .data!;

bool _connectEnabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.byKey(const Key('call.connect'))).onPressed != null;

final _timer = RegExp(r'^\d\d:\d\d$');

void main() {
  group('DemoEngine: перевод с консультацией', () {
    late DemoEngine engine;

    setUp(() => engine = DemoEngine(answerAfter: Duration.zero));
    tearDown(() => engine.dispose());

    Future<CallInfo> talk() async {
      engine.dial('1002');
      await Future<void>.delayed(Duration.zero);
      expect(engine.call.value?.phase, CallPhase.active);
      return engine.call.value!;
    }

    test('consult: первый на удержании, второй — исходящий, потом соединяется; звук там же', () async {
      final first = await talk();
      engine.setSpeaker(true);
      engine.consult('1005', name: 'Склад');
      expect(engine.other.value?.id, first.id);
      expect(engine.other.value?.held, isTrue);
      expect(engine.call.value?.phase, CallPhase.outgoing);
      expect(engine.call.value?.incoming, isFalse);
      expect(engine.call.value?.number, '1005');
      expect(engine.call.value?.speaker, isTrue);
      expect(engine.call.value?.id, isNot(first.id));
      await Future<void>.delayed(Duration.zero);
      expect(engine.call.value?.phase, CallPhase.active);
      expect(engine.call.value?.since, isNotNull);
    });

    test('consult не работает без разговора, при втором звонке и во время вызова; dial при звонке — ничего', () async {
      engine.consult('1005');
      expect(engine.call.value, isNull);

      final first = await talk();
      engine.dial('1007');
      expect(engine.call.value, first);
      expect(engine.other.value, isNull);

      engine.simulateIncoming(number: '1006');
      engine.consult('1005');
      expect(engine.call.value, first);
      expect(engine.other.value?.number, '1006');
    });

    test('connectCalls: оба звонка уходят; при отказе АТС — остаются, приходит сбой', () async {
      await talk();
      engine.consult('1005');
      await Future<void>.delayed(Duration.zero);
      final failures = <CallFailure>[];
      final sub = engine.failures.listen((e) => failures.add(e.kind));
      engine.failConnect = true;
      final call = engine.call.value;
      final other = engine.other.value;
      engine.connectCalls();
      await Future<void>.delayed(Duration.zero);
      expect(failures, [CallFailure.transfer]);
      expect(engine.call.value, call);
      expect(engine.other.value, other);

      engine.failConnect = false;
      engine.connectCalls();
      expect(engine.call.value, isNull);
      expect(engine.other.value, isNull);
      await sub.cancel();
    });

    test('connectCalls не соединяет, пока второй вызов ещё звонит', () async {
      engine = DemoEngine(answerAfter: const Duration(hours: 1));
      engine.simulateIncoming(number: '1002');
      engine.accept();
      engine.consult('1005');
      engine.connectCalls();
      expect(engine.call.value?.phase, CallPhase.outgoing);
      expect(engine.other.value?.held, isTrue);
      // Входящий во время консультации — «занято».
      engine.simulateIncoming(number: '1007');
      expect(engine.busyRejected, 1);
      // Вызов не удался — удержанный возвращается и снимается с удержания.
      engine.currentFails(CallFailure.busy);
      expect(engine.call.value?.number, '1002');
      expect(engine.call.value?.held, isFalse);
      expect(engine.other.value, isNull);
    });
  });

  testWidgets('«Сначала поговорить»: первый на удержании, второй — исходящий; «Соединить» — после ответа', (
    tester,
  ) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    final first = engine.call.value!;

    await _openTransfer(tester, '1005');
    // Оба действия на месте; «Перевести» — та же кнопка, что и раньше.
    expect(find.byKey(const Key('transfer.consult')), findsOneWidget);
    expect(find.text('Сначала поговорить'), findsOneWidget);
    expect(find.byKey(const Key('transfer.submit')), findsOneWidget);
    expect(find.text('Перевести'), findsWidgets);
    await tester.tap(find.byKey(const Key('transfer.consult')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Окно закрылось, звоним второму, первый — на строке удержания.
    expect(find.byKey(const Key('transfer.number')), findsNothing);
    expect(_title(tester), '1005');
    expect(_status(tester), 'Вызов…');
    expect(engine.call.value?.phase, CallPhase.outgoing);
    expect(engine.other.value?.id, first.id);
    expect(engine.other.value?.held, isTrue);
    expect(find.byKey(const Key('call.other')), findsOneWidget);
    expect(find.text('На удержании: 1002'), findsOneWidget);
    // Пока второй не ответил, соединять нельзя.
    expect(_connectEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('call.connect')), warnIfMissed: false);
    await tester.pump();
    expect(engine.other.value?.id, first.id);

    await _answered(tester);
    expect(_status(tester), matches(_timer));
    expect(_connectEnabled(tester), isTrue);

    await _tap(tester, 'call.connect');
    await tester.pumpAndSettle();
    expect(engine.call.value, isNull);
    expect(engine.other.value, isNull);
    expect(find.byKey(const Key('call.hangup')), findsNothing);
    // У каждого звонка своя запись: первый — исходящий, как был, консультация — тоже исходящий.
    final history = _container(tester).read(historyProvider);
    expect(history, hasLength(2));
    expect(history.map((e) => e.number), containsAll(['1002', '1005']));
    expect(history.every((e) => e.kind == CallKind.outgoing), isTrue);
  });

  testWidgets('соединить после входящего: в истории первый — входящий, консультация — исходящий', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await ringIn(tester);
    await tester.tap(find.byKey(const Key('call.accept')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_title(tester), 'Азиз Каримов');

    await _consult(tester, '1005');
    await _answered(tester);
    await _tap(tester, 'call.connect');
    await tester.pumpAndSettle();
    final history = _container(tester).read(historyProvider);
    expect(history, hasLength(2));
    expect(history.firstWhere((e) => e.number == '1002').kind, CallKind.incoming);
    expect(history.firstWhere((e) => e.number == '1005').kind, CallKind.outgoing);
  });

  testWidgets('второй вызов отклонили — первый возвращается и снимается с удержания', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _consult(tester, '1005');
    expect(engine.call.value?.phase, CallPhase.outgoing);

    engine.currentFails(CallFailure.rejected);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_title(tester), '1002');
    expect(engine.call.value?.held, isFalse);
    expect(_status(tester), matches(_timer));
    expect(find.byKey(const Key('call.other')), findsNothing);
    // Причину показали, как при обычном вызове.
    expect(find.text('Звонок отклонён'), findsWidgets);
  });

  testWidgets('человек сам завершил второй вызов — первый возвращается и снимается с удержания', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _consult(tester, '1005');

    await _tap(tester, 'call.hangup');
    expect(_title(tester), '1002');
    expect(engine.call.value?.held, isFalse);
    expect(engine.other.value, isNull);
    expect(find.byKey(const Key('call.other')), findsNothing);
    // Отменённый вызов не «отвечает» позже.
    await _answered(tester);
    expect(_title(tester), '1002');
    expect(engine.other.value, isNull);

    // И после ответа: завершили разговор со вторым — тоже возвращаемся к первому.
    await _consult(tester, '1006');
    await _answered(tester);
    await _tap(tester, 'call.hangup');
    expect(_title(tester), '1002');
    expect(engine.call.value?.held, isFalse);
    expect(_container(tester).read(historyProvider).map((e) => e.number), ['1006', '1005']);
  });

  testWidgets('АТС не соединила — оба звонка остаются, всплывает «Не удалось соединить»', (tester) async {
    final engine = DemoEngine()..failConnect = true;
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _consult(tester, '1005');
    await _answered(tester);
    final call = engine.call.value;
    final other = engine.other.value;

    await _tap(tester, 'call.connect');
    // Строку показывают все открытые экраны (как и другие сбои), поэтому ищем «хотя бы одну».
    expect(find.text('Не удалось соединить'), findsWidgets);
    expect(engine.call.value, call);
    expect(engine.other.value, other);
    expect(_title(tester), '1005');
    expect(find.text('На удержании: 1002'), findsOneWidget);
    expect(_container(tester).read(historyProvider), isEmpty);
  });

  testWidgets('«Соединить» работает и для двух звонков после ожидания (ответили на второй входящий)', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    engine.simulateIncoming(number: '1005', name: 'Склад');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tap(tester, 'call.waiting.accept');
    expect(_connectEnabled(tester), isTrue);

    await _tap(tester, 'call.connect');
    await tester.pumpAndSettle();
    expect(engine.call.value, isNull);
    expect(engine.other.value, isNull);
    final history = _container(tester).read(historyProvider);
    expect(history.firstWhere((e) => e.number == '1005').kind, CallKind.incoming);
    expect(history.firstWhere((e) => e.number == '1002').kind, CallKind.outgoing);
  });

  testWidgets('при втором звонке «Сначала поговорить» не предлагается, «Перевести» — да', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    engine.simulateIncoming(number: '1005');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tap(tester, 'call.waiting.accept');

    await _openTransfer(tester, '1007');
    expect(find.byKey(const Key('transfer.consult')), findsNothing);
    expect(find.byKey(const Key('transfer.submit')), findsOneWidget);
  });

  testWidgets('входящий во время консультации получает «занято»', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _consult(tester, '1005');

    // Пока второй вызов звонит и когда разговор уже идёт.
    engine.simulateIncoming(number: '1007', name: 'Охрана');
    await tester.pump();
    await _answered(tester);
    engine.simulateIncoming(number: '1007', name: 'Охрана');
    await tester.pump();
    expect(engine.busyRejected, 2);
    expect(find.text('Охрана'), findsNothing);
    expect(find.byKey(const Key('call.waiting')), findsNothing);
    expect(_title(tester), '1005');
    expect(find.text('На удержании: 1002'), findsOneWidget);
  });

  testWidgets('слепой перевод — как раньше: звонок переводится и завершается', (tester) async {
    final engine = _BlindSpy();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await _talk(tester);
    await _openTransfer(tester, '1005');
    await tester.tap(find.byKey(const Key('transfer.submit')));
    await tester.pumpAndSettle();
    expect(engine.transferredTo, '1005');
    expect(engine.other.value, isNull);
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('окно перевода и строка с двумя кнопками помещаются на маленьком экране во всех стилях', (tester) async {
    for (final id in SadoStyleId.values) {
      final engine = DemoEngine();
      await pumpApp(
        tester,
        saved: {...demoAccount, 'style': id.name},
        size: const Size(320, 568),
        engine: (_) => engine,
      );
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
      await tester.pumpAndSettle();
      await _talk(tester);
      final name = id.name;
      expect(tester.takeException(), isNull, reason: '$name: разговор');

      // Окно перевода с двумя действиями: всё на экране, кнопки над нижней полосой.
      await _openTransfer(tester, '1005');
      expect(tester.takeException(), isNull, reason: '$name: окно перевода');
      for (final key in ['transfer.consult', 'transfer.submit', 'transfer.number', 'transfer.key.1']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.top, greaterThanOrEqualTo(24), reason: '$name: $key');
        expect(r.bottom, lessThanOrEqualTo(568 - 48), reason: '$name: $key');
        expect(r.left, greaterThanOrEqualTo(0), reason: '$name: $key');
        expect(r.right, lessThanOrEqualTo(320), reason: '$name: $key');
      }
      await tester.tap(find.byKey(const Key('transfer.consult')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _answered(tester);

      Future<void> check(String what) async {
        expect(tester.takeException(), isNull, reason: '$name: $what');
        final hangup = tester.getRect(find.byKey(const Key('call.hangup')));
        expect(hangup.bottom, lessThanOrEqualTo(568 - 48), reason: '$name: $what — «Завершить» над полосой');
        final bar = tester.getRect(find.byKey(const Key('call.other')));
        expect(bar.top, greaterThanOrEqualTo(24), reason: '$name: $what');
        expect(bar.right, lessThanOrEqualTo(320), reason: '$name: $what');
        expect(bar.bottom, lessThanOrEqualTo(hangup.top), reason: '$name: $what');
        for (final key in ['call.swap', 'call.connect']) {
          final b = tester.getRect(find.byKey(Key(key)));
          expect(b.right, lessThanOrEqualTo(bar.right), reason: '$name: $what, $key');
          expect(b.bottom, lessThanOrEqualTo(bar.bottom + 0.01), reason: '$name: $what, $key');
        }
      }

      await check('строка с двумя кнопками');
      await _tap(tester, 'call.keypad');
      await check('строка с двумя кнопками и клавиши');
      await _tap(tester, 'call.keypadClose');

      engine.hangUp();
      engine.hangUp();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('call.hangup')), findsNothing, reason: name);
    }
  });
}

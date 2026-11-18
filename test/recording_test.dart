// Запись разговора по кнопке: когда кнопка видна, что уходит на АТС, как ведёт себя пометка «идёт запись».
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/l10n/strings.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/pbx_features.dart';
import 'package:sado/state/recording.dart';
import 'package:sado/theme/sado_style.dart';

import 'app_test.dart';

const _canRecord = PbxFeatures(conferencePrefix: '*3', recordCode: '*1');

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(SadoApp)));

/// Запускает приложение и доводит до соединённого разговора.
Future<DemoEngine> _talk(
  WidgetTester tester, {
  PbxFeatures features = _canRecord,
  Map<String, Object> saved = demoAccount,
  Size size = const Size(390, 844),
}) async {
  final engine = DemoEngine();
  await pumpApp(tester, saved: saved, engine: (_) => engine, size: size);
  _container(tester).read(pbxFeaturesProvider.notifier).set(features);
  await tester.tap(find.byKey(const Key('tab.0')));
  await tester.pumpAndSettle();
  await callAndAnswer(tester, '1002');
  return engine;
}

Future<void> _tapRecord(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('call.record')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('АТС не сообщила код записи — кнопки нет', (tester) async {
    await _talk(tester, features: const PbxFeatures(conferencePrefix: '*3'));
    expect(find.byKey(const Key('call.record')), findsNothing);
  });

  testWidgets('первое нажатие включает запись, второе выключает; на АТС уходит её код', (tester) async {
    final engine = await _talk(tester);
    expect(find.text('Записать'), findsOneWidget);
    expect(engine.sentTones, isEmpty);

    await _tapRecord(tester);
    expect(engine.sentTones, ['*1']);
    expect(find.text('Идёт запись'), findsOneWidget);
    expect(find.text('Записать'), findsNothing);

    await _tapRecord(tester);
    expect(engine.sentTones, ['*1', '*1']);
    expect(find.text('Записать'), findsOneWidget);
  });

  testWidgets('пока вызов не соединён, кнопки записи нет', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: demoAccount, engine: (_) => engine);
    _container(tester).read(pbxFeaturesProvider.notifier).set(_canRecord);
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('key.5')));
    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);
    expect(find.byKey(const Key('call.record')), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const Key('call.record')), findsOneWidget);
  });

  testWidgets('на удержании пометка видна, но нажать её нельзя', (tester) async {
    final engine = await _talk(tester);
    await _tapRecord(tester);
    // «Удержать» в стиле по умолчанию стоит на экране сразу.
    await tester.tap(find.byKey(const Key('call.hold')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Идёт запись'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.record')), warnIfMissed: false);
    await tester.pump();
    expect(engine.sentTones, ['*1'], reason: 'на удержании код до АТС не дошёл бы — не шлём');
    expect(find.text('Идёт запись'), findsOneWidget);
  });

  testWidgets('разговор закончился — у следующего запись снова выключена', (tester) async {
    final engine = await _talk(tester);
    await _tapRecord(tester);
    expect(_container(tester).read(recordingProvider), isNotEmpty);
    engine.hangUp();
    await tester.pumpAndSettle();
    expect(_container(tester).read(recordingProvider), isEmpty);

    await callAndAnswer(tester, '1002');
    expect(find.text('Записать'), findsOneWidget);
    expect(find.text('Идёт запись'), findsNothing);
  });

  testWidgets('два разговора: пометка записи принадлежит своему разговору', (tester) async {
    final engine = await _talk(tester);
    await _tapRecord(tester);
    // Второй звонок: отвечаем — первый (с записью) уходит на удержание.
    engine.simulateIncoming(number: '1005', name: 'Склад');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('call.waiting.accept')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Записать'), findsOneWidget, reason: 'второй разговор не записывается');

    await tester.tap(find.byKey(const Key('call.swap')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Идёт запись'), findsOneWidget, reason: 'вернулись к разговору, который записывается');
  });

  testWidgets('с кнопкой записи экран разговора помещается на маленьком телефоне на каждом языке и в каждом стиле', (
    tester,
  ) async {
    for (final lang in S.languageNames.keys) {
      for (final id in [SadoStyleId.emerald, SadoStyleId.cupertino, SadoStyleId.material]) {
        final where = 'язык $lang, стиль ${id.name}';
        final engine = await _talk(
          tester,
          saved: {...demoAccount, 'lang': lang, 'style': id.name},
          size: const Size(320, 568),
        );
        // Строка состояния сверху и три кнопки навигации снизу — как на недорогом телефоне.
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$where: разговор');
        await _tapRecord(tester);
        expect(tester.takeException(), isNull, reason: '$where: идёт запись');
        expect(find.text(S.byCode(lang).recordingOn), findsOneWidget, reason: where);

        // Самый тесный случай: второй разговор на удержании и кнопка записи одновременно.
        engine.simulateIncoming(number: '1005', name: 'Purchasing and logistics, warehouse 2');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$where: второй входящий');
        await tester.tap(find.byKey(const Key('call.waiting.accept')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$where: два разговора');
        final hangup = tester.getRect(find.byKey(const Key('call.hangup')));
        expect(hangup.bottom, lessThanOrEqualTo(568 - 48), reason: '$where: «Завершить» над полосой навигации');

        await tester.tap(find.byKey(const Key('call.keypad')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$where: клавиши донабора');
        engine.hangUp();
        await tester.pumpAndSettle();
        engine.hangUp();
        await tester.pumpAndSettle();
      }
    }
  });
}

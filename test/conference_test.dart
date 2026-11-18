// Конференция «Объединить»: кнопка на строке удержанного звонка, номер временной комнаты, сбой.
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/l10n/strings.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/pbx_features.dart';
import 'package:sado/theme/sado_style.dart';

import 'app_test.dart';

const _sado = PbxFeatures(conferencePrefix: '*3');

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(SadoApp)));

/// Запускает приложение и доводит до двух разговоров: первый на удержании, второй — текущий.
Future<DemoEngine> _twoCalls(
  WidgetTester tester, {
  PbxFeatures features = _sado,
  Map<String, Object> saved = demoAccount,
  Size size = const Size(390, 844),
}) async {
  final engine = DemoEngine();
  await pumpApp(tester, saved: saved, engine: (_) => engine, size: size);
  _container(tester).read(pbxFeaturesProvider.notifier).set(features);
  await tester.tap(find.byKey(const Key('tab.0')));
  await tester.pumpAndSettle();
  await callAndAnswer(tester, '1002');
  engine.simulateIncoming(number: '1005', name: 'Склад');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const Key('call.waiting.accept')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return engine;
}

void main() {
  test('номер комнаты: префикс и случайный код нужной длины', () {
    final rooms = {for (var i = 0; i < 50; i++) _sado.newConferenceRoom()};
    for (final room in rooms) {
      expect(room, matches(RegExp(r'^\*3\d{6}$')));
    }
    // Код действительно меняется от раза к разу.
    expect(rooms.length, greaterThan(40));
    expect(
      const PbxFeatures(conferencePrefix: '88', conferenceDigits: 4).newConferenceRoom(Random(1)),
      matches(RegExp(r'^88\d{4}$')),
    );
  });

  test('без префикса конференции нет', () {
    expect(PbxFeatures.none.canConference, isFalse);
    expect(const PbxFeatures(conferencePrefix: '').canConference, isFalse);
    expect(_sado.canConference, isTrue);
  });

  testWidgets('АТС не умеет конференцию — кнопки «Объединить» нет', (tester) async {
    await _twoCalls(tester, features: PbxFeatures.none);
    expect(find.byKey(const Key('call.other')), findsOneWidget);
    expect(find.byKey(const Key('call.connect')), findsOneWidget);
    expect(find.byKey(const Key('call.merge')), findsNothing);
  });

  testWidgets('«Объединить»: оба разговора уходят в комнату, на экране — один звонок «Конференция»', (tester) async {
    final engine = await _twoCalls(tester);
    expect(find.text('Объединить'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.merge')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(engine.conferenceRoom, matches(RegExp(r'^\*3\d{6}$')));
    expect(engine.other.value, isNull);
    expect(engine.call.value?.number, engine.conferenceRoom);
    expect(engine.call.value?.phase, CallPhase.active);
    // Строки удержанного звонка больше нет, а разговор подписан понятным словом, а не кодом.
    expect(find.byKey(const Key('call.other')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('call.title'))).data, 'Конференция');
    expect(find.byKey(const Key('call.hangup')), findsOneWidget);
  });

  testWidgets('пока второй вызов не соединён, «Объединить» неактивна', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: demoAccount, engine: (_) => engine);
    _container(tester).read(pbxFeaturesProvider.notifier).set(_sado);
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    await callAndAnswer(tester, '1002');
    // «Сначала поговорить»: второй вызов ещё звонит.
    engine.consult('1005');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('call.merge'))).onPressed, isNull);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('call.merge'))).onPressed, isNotNull);
  });

  testWidgets('АТС не объединила — оба звонка остаются, человек видит сообщение', (tester) async {
    final engine = await _twoCalls(tester);
    engine.failConnect = true;
    await tester.tap(find.byKey(const Key('call.merge')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(engine.conferenceRoom, isNull);
    expect(engine.call.value, isNotNull);
    expect(engine.other.value, isNotNull);
    expect(find.text('Не удалось соединить'), findsWidgets);
  });

  testWidgets('три кнопки на строке удержания помещаются на маленьком экране на каждом языке и в каждом стиле', (
    tester,
  ) async {
    for (final lang in S.languageNames.keys) {
      for (final id in [SadoStyleId.emerald, SadoStyleId.cupertino, SadoStyleId.material]) {
        final engine = await _twoCalls(
          tester,
          saved: {...demoAccount, 'lang': lang, 'style': id.name},
          size: const Size(320, 568),
        );
        expect(tester.takeException(), isNull, reason: 'язык $lang, стиль ${id.name}');
        expect(find.byKey(const Key('call.merge')), findsOneWidget, reason: 'язык $lang, стиль ${id.name}');
        final strip = tester.getRect(find.byKey(const Key('call.other')));
        final merge = tester.getRect(find.byKey(const Key('call.merge')));
        expect(merge.right, lessThanOrEqualTo(strip.right + 0.5), reason: 'язык $lang, стиль ${id.name}');
        expect(merge.left, greaterThanOrEqualTo(strip.left - 0.5), reason: 'язык $lang, стиль ${id.name}');
        engine.hangUp();
        await tester.pumpAndSettle();
        engine.hangUp();
        await tester.pumpAndSettle();
      }
    }
  });
}

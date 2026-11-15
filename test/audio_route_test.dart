import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/call.dart';
import 'package:sado/theme/sado_style.dart';

import 'app_test.dart';

CallInfo? currentCall(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SadoApp))).read(callProvider);

void main() {
  testWidgets('с трубкой и динамиком кнопка просто переключает, листа нет', (tester) async {
    await pumpApp(tester, saved: demoAccount, engine: (_) => DemoEngine());
    await callAndAnswer(tester, '5');

    await tester.tap(find.byKey(const Key('call.speaker')));
    await tester.pump();
    expect(find.byKey(const Key('output.speaker')), findsNothing);
    expect(currentCall(tester)!.speaker, isTrue);

    await tester.tap(find.byKey(const Key('call.speaker')));
    await tester.pump();
    expect(currentCall(tester)!.speaker, isFalse);
    expect(currentCall(tester)!.route, AudioKind.earpiece);
  });

  testWidgets('с Bluetooth кнопка открывает лист; выбор Bluetooth и динамика', (tester) async {
    await pumpApp(
      tester,
      saved: demoAccount,
      engine: (_) => DemoEngine(extraRoutes: const [AudioRoute(AudioKind.bluetooth, 'Buds')]),
    );
    await callAndAnswer(tester, '5');

    await tester.tap(find.byKey(const Key('call.speaker')));
    await tester.pumpAndSettle();
    expect(find.text('Куда выводить звук'), findsOneWidget);
    expect(find.text('Телефон'), findsOneWidget);
    expect(find.text('Bluetooth · Buds'), findsOneWidget);
    // Сейчас выбрана трубка — галочка одна.
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byKey(const Key('output.bluetooth')));
    await tester.pumpAndSettle();
    expect(find.text('Куда выводить звук'), findsNothing);
    expect(currentCall(tester)!.route, AudioKind.bluetooth);
    expect(currentCall(tester)!.speaker, isFalse);
    expect(find.byIcon(Icons.bluetooth_audio), findsOneWidget);

    await tester.tap(find.byKey(const Key('call.speaker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('output.speaker')));
    await tester.pumpAndSettle();
    expect(currentCall(tester)!.speaker, isTrue);
    expect(currentCall(tester)!.route, AudioKind.speaker);
  });

  testWidgets('лист закрывается сам, когда звонок закончился', (tester) async {
    await pumpApp(
      tester,
      saved: demoAccount,
      engine: (_) => DemoEngine(extraRoutes: const [AudioRoute(AudioKind.wired)]),
    );
    await callAndAnswer(tester, '5');
    await tester.tap(find.byKey(const Key('call.speaker')));
    await tester.pumpAndSettle();
    expect(find.text('Наушники'), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byType(SadoApp))).read(callProvider.notifier).hangUp();
    await tester.pumpAndSettle();
    expect(find.text('Наушники'), findsNothing);
  });

  for (final id in SadoStyleId.values) {
    testWidgets('лист звука помещается на 320×568 в стиле ${id.name}', (tester) async {
      await pumpApp(
        tester,
        saved: {...demoAccount, 'style': id.name},
        engine: (_) => DemoEngine(
          extraRoutes: const [
            AudioRoute(AudioKind.bluetooth, 'Очень длинное название гарнитуры Bluetooth'),
            AudioRoute(AudioKind.wired),
          ],
        ),
        size: const Size(320, 568),
      );
      await callAndAnswer(tester, '5');
      await tester.tap(find.byKey(const Key('call.speaker')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('output.bluetooth')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

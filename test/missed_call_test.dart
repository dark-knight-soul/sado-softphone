import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/sip/demo_engine.dart';

import 'app_test.dart';

/// Звонивший не дождался ответа и положил трубку (на стороне АТС вызов просто пропадает).
Future<void> callerGivesUp(WidgetTester tester, DemoEngine engine) async {
  engine.hangUp();
  await tester.pumpAndSettle();
}

List<String> missedLog() => keeper.log.where((e) => e.startsWith('missed:')).toList();

void main() {
  testWidgets('пропущенный звонок: одно уведомление с именем звонившего', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await ringIn(tester);
    expect(missedLog(), isEmpty);
    await callerGivesUp(tester, engine);
    expect(missedLog(), ['missed: Пропущенный звонок | Азиз Каримов']);
  });

  testWidgets('два пропущенных: в заголовке число 2', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    for (var i = 0; i < 2; i++) {
      await ringIn(tester);
      await callerGivesUp(tester, engine);
    }
    expect(missedLog().last, 'missed: Пропущенные звонки: 2 | Азиз Каримов, Азиз Каримов');
  });

  testWidgets('звонок отклонён самим человеком: в истории он пропущенный, но уведомления нет', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret', engine: (_) => engine);
    await ringIn(tester);
    await tester.tap(find.byKey(const Key('call.decline')));
    await tester.pumpAndSettle();
    expect(missedLog(), isEmpty);

    // Следующий звонок, на который просто не ответили, уведомляет как обычно — отметка «отклонил сам» не залипает.
    await ringIn(tester);
    await callerGivesUp(tester, engine);
    expect(missedLog(), ['missed: Пропущенный звонок | Азиз Каримов']);
  });

  testWidgets('демонстрационная учётная запись: уведомления нет', (tester) async {
    final engine = DemoEngine();
    await pumpApp(tester, saved: demoAccount, engine: (_) => engine);
    await ringIn(tester);
    await callerGivesUp(tester, engine);
    expect(missedLog(), isEmpty);
  });

  testWidgets('«Не беспокоить»: отклонённый автоматически тоже даёт уведомление', (tester) async {
    await pumpApp(tester, saved: {...realAccount, 'dnd': true}, savedPassword: 'secret');
    await ringIn(tester);
    expect(missedLog(), ['missed: Пропущенный звонок | Азиз Каримов']);
  });
}

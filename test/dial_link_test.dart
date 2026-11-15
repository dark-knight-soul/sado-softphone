import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/theme/sado_style.dart';

import 'app_test.dart';

/// Текст в поле набора (поле видно только на вкладке набора: остальные вкладки скрыты).
String? _dialed(WidgetTester tester) {
  final field = find.byKey(const Key('dialer.number'));
  return field.evaluate().isEmpty ? null : tester.widget<Text>(field).data;
}

void main() {
  tearDown(() => pendingDialOnStart = null);

  testWidgets('номер из ссылки при запуске попадает в поле набора', (tester) async {
    pendingDialOnStart = '1004';
    await pumpApp(tester, saved: demoAccount);
    expect(_dialed(tester), '1004');
    // Звонок сам не начался.
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('ссылка при открытом приложении переключает на набор', (tester) async {
    await pumpApp(tester, saved: demoAccount);
    await tester.tap(find.byKey(Key('tab.${AppTab.history.index}')));
    await tester.pumpAndSettle();
    expect(_dialed(tester), isNull, reason: 'экран набора скрыт');

    keeper.onDialRequest!('1005');
    await tester.pumpAndSettle();
    expect(_dialed(tester), '1005');
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('мусор из ссылки очищается', (tester) async {
    await pumpApp(tester, saved: demoAccount);
    const raw = '100@evil.example;x=1';
    keeper.onDialRequest!(raw);
    await tester.pumpAndSettle();
    final shown = _dialed(tester)!;
    expect(shown, dialTarget(raw));
    expect(shown, isNot(contains('@')));
    expect(shown, isNot(contains(';')));
    expect(shown, isNot(contains('=')));
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });

  testWidgets('без входа в учётную запись ссылка отбрасывается', (tester) async {
    await pumpApp(tester);
    keeper.onDialRequest!('1005');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialer.number')), findsNothing);
    expect(find.byKey(const Key('call.hangup')), findsNothing);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/theme/sado_style.dart';

import 'app_test.dart';

/// Открывает настройки и докручивает до строки с данным ключом.
Future<void> _openSettingsAt(WidgetTester tester, String key) async {
  // В «Материале» настройки открываются значком меню на главном экране, а не вкладкой.
  if (find.byKey(const Key('tab.3')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('tab.1')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('tab.3')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(Key(key)), 120, scrollable: scrollableOf('settings.list'));
  await tester.pumpAndSettle();
}

/// Есть ли в строке настроек с ключом [key] данный текст.
bool _rowHasText(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text)).evaluate().isNotEmpty;

/// Включён ли переключатель вибрации.
bool _vibrationOn(WidgetTester tester) =>
    tester.widget<Switch>(find.byKey(const Key('settings.ringVibration.switch'))).value;

void main() {
  testWidgets('мелодия: по умолчанию «Как в телефоне», после выбора — название мелодии', (tester) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');
    await _openSettingsAt(tester, 'settings.ringtone');

    expect(find.text('Мелодия звонка'), findsOneWidget);
    expect(_rowHasText('settings.ringtone', 'Как в телефоне'), isTrue);
    expect(find.byKey(const Key('settings.ringVibration')), findsOneWidget);
    expect(_vibrationOn(tester), isTrue);

    keeper.pickedRingtone = 'Утренняя трель';
    await tester.tap(find.byKey(const Key('settings.ringtone')));
    await tester.pumpAndSettle();
    expect(keeper.log.last, 'pickRingtone');
    expect(_rowHasText('settings.ringtone', 'Утренняя трель'), isTrue);
    expect(_rowHasText('settings.ringtone', 'Как в телефоне'), isFalse);
  });

  testWidgets('вибрация: выключение доходит до телефона, строка показывает новое значение', (tester) async {
    await pumpApp(tester, saved: realAccount, savedPassword: 'secret');
    await _openSettingsAt(tester, 'settings.ringVibration');

    expect(_vibrationOn(tester), isTrue);
    await tester.tap(find.byKey(const Key('settings.ringVibration.switch')));
    await tester.pumpAndSettle();
    expect(keeper.log.last, 'setRingVibration: false');
    expect(keeper.ringState.vibrate, isFalse);
    expect(_vibrationOn(tester), isFalse);

    // Выбор мелодии вибрацию не сбрасывает.
    await tester.ensureVisible(find.byKey(const Key('settings.ringtone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.ringtone')));
    await tester.pumpAndSettle();
    expect(_vibrationOn(tester), isFalse);

    // Нажатие на саму строку тоже переключает.
    await tester.tap(find.byKey(const Key('settings.ringVibration')));
    await tester.pumpAndSettle();
    expect(keeper.log.last, 'setRingVibration: true');
    expect(_vibrationOn(tester), isTrue);
  });

  testWidgets('в демонстрации строк мелодии и вибрации нет', (tester) async {
    await pumpApp(tester, saved: demoAccount);
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.demoIncoming')),
      120,
      scrollable: scrollableOf('settings.list'),
    );
    expect(find.byKey(const Key('settings.ringtone')), findsNothing);
    expect(find.byKey(const Key('settings.ringVibration')), findsNothing);
  });

  testWidgets('строки мелодии и вибрации помещаются на маленьком телефоне во всех стилях', (tester) async {
    for (final id in SadoStyleId.values) {
      await pumpApp(
        tester,
        saved: {...realAccount, 'style': id.name},
        savedPassword: 'secret',
        size: const Size(320, 568),
      );
      await _openSettingsAt(tester, 'settings.ringtone');
      // Длинное название мелодии не должно распирать строку.
      keeper.pickedRingtone = 'Очень длинное название мелодии звонка, которое не помещается';
      await tester.tap(find.byKey(const Key('settings.ringtone')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings.ringVibration')),
        120,
        scrollable: scrollableOf('settings.list'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: id.name);
      expect(find.byKey(const Key('settings.ringtone')), findsOneWidget, reason: id.name);
      final row = tester.getRect(find.byKey(const Key('settings.ringVibration')));
      expect(row.right, lessThanOrEqualTo(320), reason: id.name);
    }
  });
}

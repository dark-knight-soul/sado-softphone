// Языки интерфейса: у каждого есть перевод, подстановки на месте, а надписи помещаются
// на маленьком телефоне на всех основных экранах.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/l10n/strings.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/theme/sado_style.dart';

import 'app_test.dart';

/// Надписи, которые на любом языке, кроме английского, обязаны отличаться от английских.
List<String> _sample(S s) => [
  s.signIn,
  s.call,
  s.settings,
  s.language,
  s.decline,
  s.cancel,
  s.save,
  s.delete,
  s.today,
  s.yesterdayTitle,
  s.incomingCall,
  s.missedCallTitle,
  s.searchHint,
  s.transferTitle,
  s.checkUpdates,
];

void main() {
  test('у каждого языка есть и перевод, и название в списке выбора', () {
    expect(S.languageNames.keys.toSet(), {for (final l in S.supportedLocales) l.languageCode});
  });

  test('язык телефона без перевода: английский, а для соседних с русским — русский', () {
    expect(S.resolveCode('de'), 'de');
    expect(S.resolveCode('ja'), 'en');
    expect(S.resolveCode('kk'), 'ru');
    expect(S.resolveLocale(const Locale('fr', 'CA'), S.supportedLocales), const Locale('fr'));
    expect(S.resolveLocale(const Locale('zh'), S.supportedLocales), const Locale('en'));
    expect(S.resolveLocale(null, S.supportedLocales), const Locale('en'));
  });

  test('каждый язык переведён, а не оставлен копией английского', () {
    final en = _sample(S.byCode('en'));
    for (final code in S.languageNames.keys.where((c) => c != 'en')) {
      final own = _sample(S.byCode(code));
      for (var i = 0; i < en.length; i++) {
        expect(own[i], isNot(en[i]), reason: 'язык $code: «${en[i]}» не переведено');
        expect(own[i].trim(), isNotEmpty, reason: 'язык $code, надпись $i');
      }
    }
  });

  test('подстановки (номер, число, версия) есть в каждом языке', () {
    for (final code in S.languageNames.keys) {
      final s = S.byCode(code);
      for (final text in [s.online('1003'), s.linkConnecting('1003'), s.linkOffline('1003'), s.linkAuth('1003')]) {
        expect(text, contains('1003'), reason: code);
      }
      expect(s.dndStatus('1003'), contains('1003'), reason: code);
      expect(s.minutes(5), contains('5'), reason: code);
      expect(s.seconds(7), contains('7'), reason: code);
      expect(s.missedCallsTitle(3), contains('3'), reason: code);
      expect(s.versionLabel('1.2.3'), contains('1.2.3'), reason: code);
      expect(s.updateAvailable('9.8.7'), contains('9.8.7'), reason: code);
      expect(s.caller(null, ''), s.unknownCaller, reason: code);
      for (final id in SadoStyleId.values) {
        expect(s.styleName(id).trim(), isNotEmpty, reason: '$code, стиль ${id.name}');
      }
    }
  });

  testWidgets('все основные экраны помещаются на маленьком телефоне на каждом языке', (tester) async {
    for (final lang in S.languageNames.keys) {
      for (final id in [SadoStyleId.emerald, SadoStyleId.cupertino, SadoStyleId.material]) {
        final where = 'язык $lang, стиль ${id.name}';
        void ok(String screen) => expect(tester.takeException(), isNull, reason: '$where: $screen');

        final engine = DemoEngine();
        await pumpApp(
          tester,
          saved: {...demoAccount, 'lang': lang, 'style': id.name},
          size: const Size(320, 568),
          engine: (_) => engine,
        );
        // Строка состояния сверху и три кнопки навигации снизу — как на недорогом телефоне.
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
        await tester.pumpAndSettle();
        ok('первый экран');

        for (var tab = 0; tab < 4; tab++) {
          await tester.tap(find.byKey(Key('tab.$tab')));
          await tester.pumpAndSettle();
          ok('вкладка $tab');
        }

        // Настройки: список выбора языка и весь список до конца.
        final language = find.byKey(const Key('settings.language'));
        await tester.scrollUntilVisible(language, 120, scrollable: scrollableOf('settings.list'));
        // Строка могла показаться у самого низа, под нижним меню — ставим её ближе к середине экрана.
        await Scrollable.ensureVisible(tester.element(language), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(language);
        await tester.pumpAndSettle();
        ok('список языков');
        expect(find.text(S.languageNames['uz']!), findsWidgets, reason: '$where: список языков открыт');
        Navigator.of(tester.element(find.text(S.languageNames['uz']!).last)).pop();
        await tester.pumpAndSettle();
        for (var i = 0; i < 8; i++) {
          await tester.drag(scrollableOf('settings.list'), const Offset(0, -350));
          await tester.pumpAndSettle();
          ok('настройки, прокрутка $i');
        }

        // Входящий звонок.
        await ringIn(tester);
        ok('входящий');
        engine.hangUp();
        await tester.pumpAndSettle();

        // Разговор, клавиши донабора, окно перевода.
        await tester.tap(find.byKey(const Key('tab.0')));
        await tester.pumpAndSettle();
        await callAndAnswer(tester, '1002');
        ok('разговор');
        await tester.tap(find.byKey(const Key('call.keypad')));
        await tester.pump();
        ok('клавиши донабора');
        await tester.tap(find.byKey(const Key('call.keypadClose')));
        await tester.pump();
        if (find.byKey(const Key('call.transfer')).hitTestable().evaluate().isEmpty) {
          await tester.tap(find.byKey(const Key('call.more')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          ok('меню «Ещё»');
        }
        await tester.tap(find.byKey(const Key('call.transfer')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        for (final d in '1005'.split('')) {
          await tester.tap(find.byKey(Key('transfer.key.$d')));
        }
        await tester.pump();
        ok('окно перевода');

        // «Сначала поговорить»: два разговора и строка с «Поменять» и «Соединить».
        await tester.tap(find.byKey(const Key('transfer.consult')));
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        ok('два разговора');
        engine.hangUp();
        await tester.pumpAndSettle();
        engine.hangUp();
        await tester.pumpAndSettle();

        // Второй входящий во время разговора — карточка с «Ответить» и «Отклонить».
        await tester.tap(find.byKey(const Key('tab.0')));
        await tester.pumpAndSettle();
        await callAndAnswer(tester, '1002');
        engine.simulateIncoming(number: '1005', name: 'Purchasing and logistics, warehouse 2');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        ok('второй входящий');
        engine.hangUp();
        await tester.pumpAndSettle();
        engine.hangUp();
        await tester.pumpAndSettle();
      }
    }
  });
}

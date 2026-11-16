// Статусы контактов: разбор уведомления АТС и показ в списке контактов.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/data/demo_data.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/sip/pidf.dart';

import 'app_test.dart';

/// Тело уведомления в том виде, как его присылает Asterisk (снято со стенда).
String _asterisk(String note, String basic) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<presence entity="sip:1002@pbx.example.com" xmlns="urn:ietf:params:xml:ns:pidf" xmlns:dm="urn:ietf:params:xml:ns:pidf:data-model" xmlns:rpid="urn:ietf:params:xml:ns:pidf:rpid">
 <note>$note</note>
 <tuple id="1002">
  <status>
   <basic>$basic</basic>
  </status>
  <contact priority="1">sip:1003@pbx.example.com</contact>
 </tuple>
 <dm:person />
</presence>''';

String _contacts() => jsonEncode([
  {'name': 'Азиз Каримов', 'number': '1002'},
  {'name': 'Склад', 'number': '1010'},
  {'name': 'Поставщик', 'number': '+998901234567'},
]);

void main() {
  test('разбор статуса: свободен, говорит, не в сети', () {
    expect(presenceFromPidf(_asterisk('Ready', 'open')), Presence.free);
    expect(presenceFromPidf(_asterisk('On the phone', 'open')), Presence.busy);
    expect(presenceFromPidf(_asterisk('Ringing', 'open')), Presence.busy);
    expect(presenceFromPidf(_asterisk('On hold', 'open')), Presence.busy);
    expect(presenceFromPidf(_asterisk('Unavailable', 'closed')), Presence.offline);
  });

  test('разбор статуса: значки занятости из RFC 4480 и тело с приставками', () {
    const body =
        '<pidf:presence xmlns:pidf="urn:ietf:params:xml:ns:pidf"><pidf:tuple id="a"><pidf:status>'
        '<pidf:basic>open</pidf:basic></pidf:status></pidf:tuple>'
        '<dm:person><rpid:activities><rpid:on-the-phone/></rpid:activities></dm:person></pidf:presence>';
    expect(presenceFromPidf(body), Presence.busy);
    expect(presenceFromPidf(body.replaceAll('<rpid:on-the-phone/>', '<rpid:busy />')), Presence.busy);
    expect(presenceFromPidf(body.replaceAll('<rpid:on-the-phone/>', '')), Presence.free);
  });

  test('разбор статуса: непонятное тело статуса не даёт', () {
    expect(presenceFromPidf(null), isNull);
    expect(presenceFromPidf(''), isNull);
    expect(presenceFromPidf('<presence></presence>'), isNull);
    expect(presenceFromPidf('not xml at all'), isNull);
  });

  test('следим только за короткими номерами из цифр', () {
    expect(isExtensionLike('1002'), isTrue);
    expect(isExtensionLike('22'), isTrue);
    expect(isExtensionLike('+998901234567'), isFalse);
    expect(isExtensionLike('901234567'), isFalse);
    expect(isExtensionLike('reception'), isFalse);
    expect(isExtensionLike('*43'), isFalse);
    expect(isExtensionLike(''), isFalse);
  });

  testWidgets('список контактов показывает статус от АТС и обновляет его', (tester) async {
    final engine = DemoEngine();
    await pumpApp(
      tester,
      saved: {...realAccount, 'contacts': _contacts()},
      savedPassword: 'secret',
      engine: (_) => engine,
    );
    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();

    // За статусами просим следить по всем своим контактам; какие из них годятся, решает движок.
    expect(engine.watchedNumbers, {'1002', '1010', '+998901234567'});
    // Пока АТС ничего не сообщила — под именем просто номер.
    expect(find.text('1002'), findsOneWidget);

    engine.presence.value = {'1002': Presence.busy, '1010': Presence.free};
    await tester.pump();
    expect(find.text('разговаривает · 1002'), findsOneWidget);
    expect(find.text('свободен · 1010'), findsOneWidget);

    engine.presence.value = {'1002': Presence.offline};
    await tester.pump();
    expect(find.text('не в сети · 1002'), findsOneWidget);
    expect(find.text('1010'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('новый контакт сразу попадает под наблюдение', (tester) async {
    final engine = DemoEngine();
    await pumpApp(
      tester,
      saved: {...realAccount, 'contacts': _contacts()},
      savedPassword: 'secret',
      engine: (_) => engine,
    );
    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    expect(engine.watchedNumbers, isNot(contains('1020')));

    await tester.tap(find.byKey(const Key('contacts.add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact.name')), 'Бухгалтерия');
    await tester.enterText(find.byKey(const Key('contact.number')), '1020');
    await tester.tap(find.byKey(const Key('contact.save')));
    await tester.pumpAndSettle();

    expect(engine.watchedNumbers, contains('1020'));
  });
}

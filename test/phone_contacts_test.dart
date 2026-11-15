import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado/app.dart';
import 'package:sado/data/demo_data.dart';
import 'package:sado/platform/call_keeper.dart';
import 'package:sado/platform/phone_contacts.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/call.dart';
import 'package:sado/state/contacts.dart';
import 'package:sado/state/password_store.dart';
import 'package:sado/state/session.dart';
import 'package:sado/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart';

/// Адресная книга телефона из памяти: разрешение и список задаются тестом.
class FakePhoneContacts extends PhoneContacts {
  FakePhoneContacts(this.items, {this.allowed = false, this.grantOnRequest = true});

  final List<Contact> items;
  bool allowed;

  /// Что ответит человек на вопрос о разрешении.
  bool grantOnRequest;
  int requests = 0;

  @override
  Future<bool> granted() async => allowed;

  @override
  Future<bool> request() async {
    requests++;
    allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<List<Contact>> list() async => items;
}

const _phoneBook = [
  Contact(name: 'Зафар Телефонов', number: '+998 90 123-45-67'),
  Contact(name: 'Алина Книгина', number: '+998 71 200-00-01'),
  Contact(name: 'Алина Книгина', number: '+998 71 200-00-02'),
];

/// Как `pumpApp`, но с подменой адресной книги телефона.
Future<void> pumpWithPhone(
  WidgetTester tester,
  FakePhoneContacts phone, {
  Map<String, Object> saved = realAccount,
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        passwordStoreProvider.overrideWithValue(MemoryPasswordStore(saved == demoAccount ? null : 'secret')),
        engineFactoryProvider.overrideWithValue((_) => DemoEngine()),
        callKeeperProvider.overrideWithValue(keeper = RecordingKeeper()),
        phoneContactsProvider.overrideWithValue(phone),
      ],
      child: const SadoApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tab.2')));
  await tester.pumpAndSettle();
}

Future<void> _enable(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('contacts.phone')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('по умолчанию выключено: кнопка есть, контактов телефона нет', (tester) async {
    final phone = FakePhoneContacts(_phoneBook, allowed: true);
    await pumpWithPhone(tester, phone);
    expect(find.byKey(const Key('contacts.phone')), findsOneWidget);
    expect(find.text('Показать контакты телефона'), findsOneWidget);
    expect(find.text('Из телефона'), findsNothing);
    expect(find.text('Зафар Телефонов'), findsNothing);
  });

  testWidgets('разрешили: раздел «Из телефона», поиск фильтрует, у контакта с двумя номерами две строки', (
    tester,
  ) async {
    final phone = FakePhoneContacts(_phoneBook);
    await pumpWithPhone(tester, phone);
    await _enable(tester);

    expect(phone.requests, 1);
    expect(find.byKey(const Key('contacts.phone')), findsNothing);
    expect(find.text('Из телефона'), findsOneWidget);
    expect(find.text('Зафар Телефонов'), findsOneWidget);
    expect(find.text('Алина Книгина'), findsNWidgets(2));
    // Сортировка по имени: «Алина» выше «Зафара».
    expect(
      tester.getTopLeft(find.text('Зафар Телефонов')).dy,
      greaterThan(tester.getTopLeft(find.text('Алина Книгина').first).dy),
    );

    await tester.enterText(find.byKey(const Key('contacts.search')), 'зафар');
    await tester.pumpAndSettle();
    expect(find.text('Зафар Телефонов'), findsOneWidget);
    expect(find.text('Алина Книгина'), findsNothing);
  });

  testWidgets('нажатие на контакт телефона звонит; долгое нажатие меню не открывает', (tester) async {
    await pumpWithPhone(tester, FakePhoneContacts(_phoneBook));
    await _enable(tester);

    // Долгое удержание меню не открывает (звонок при этом начинается, как при обычном нажатии).
    await tester.longPress(find.text('Зафар Телефонов'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('contact.edit')), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(SadoApp)));
    final call = container.read(callProvider);
    expect(call?.number, '+998 90 123-45-67');
    expect(call?.name, 'Зафар Телефонов');
    container.read(callProvider.notifier).hangUp();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('отказали: всё остаётся выключенным', (tester) async {
    final phone = FakePhoneContacts(_phoneBook, grantOnRequest: false);
    await pumpWithPhone(tester, phone);
    await _enable(tester);

    expect(phone.requests, 1);
    expect(find.byKey(const Key('contacts.phone')), findsOneWidget);
    expect(find.text('Из телефона'), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(SadoApp)));
    expect(container.read(settingsProvider).phoneContacts, isFalse);
  });

  testWidgets('тот же номер среди своих контактов: контакт телефона скрыт', (tester) async {
    final own = jsonEncode([
      {'name': 'Зафар Свой', 'number': '+998901234567'},
    ]);
    await pumpWithPhone(tester, FakePhoneContacts(_phoneBook), saved: {...realAccount, 'contacts': own});
    await _enable(tester);

    expect(find.text('Зафар Свой'), findsOneWidget);
    expect(find.text('Зафар Телефонов'), findsNothing);
    expect(find.text('Алина Книгина'), findsNWidgets(2));
  });

  testWidgets('nameOf находит контакт телефона, номера сравниваются по цифрам', (tester) async {
    await pumpWithPhone(tester, FakePhoneContacts(_phoneBook));
    await _enable(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(SadoApp)));
    final nameOf = container.read(contactsProvider.notifier).nameOf;

    expect(nameOf('+998901234567'), 'Зафар Телефонов');
    expect(nameOf('+998 90 123-45-67'), 'Зафар Телефонов');
    // Без плюса это другой номер.
    expect(nameOf('998901234567'), isNull);
    expect(nameOf('1234'), isNull);
    expect(normalizeNumber('+998 (90) 123-45-67'), '+998901234567');
    expect(normalizeNumber('8 800 555'), '8800555');
  });

  testWidgets('демонстрационная учётная запись: кнопки нет', (tester) async {
    await pumpWithPhone(tester, FakePhoneContacts(_phoneBook, allowed: true), saved: demoAccount);
    expect(find.byKey(const Key('contacts.phone')), findsNothing);
    expect(find.text('Из телефона'), findsNothing);
  });

  testWidgets('выключатель в настройках прячет контакты телефона', (tester) async {
    await pumpWithPhone(tester, FakePhoneContacts(_phoneBook));
    await _enable(tester);
    expect(find.text('Из телефона'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('settings.phoneContacts'));
    await tester.scrollUntilVisible(row, 120, scrollable: scrollableOf('settings.list'));
    await tester.tap(find.descendant(of: row, matching: find.text('Выключено')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    expect(find.text('Из телефона'), findsNothing);
    expect(find.byKey(const Key('contacts.phone')), findsOneWidget);
  });

  testWidgets('раздел «Из телефона» помещается на экране 320×568', (tester) async {
    await pumpWithPhone(tester, FakePhoneContacts(_phoneBook), size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await _enable(tester);
    expect(find.text('Из телефона'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

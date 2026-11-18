// Справочник сотрудников с АТС: разбор ответа, когда и с чем приложение ходит на сервер, показ в контактах.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/call.dart';
import 'package:sado/state/directory.dart';
import 'package:sado/state/pbx_features.dart';
import 'package:sado/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart';

/// Ответ сервера в том виде, как его отдаёт АТС (снят со стенда, имена выдуманы).
String _body({String? record}) => jsonEncode({
  'self': '1003',
  'entries': [
    {'number': '1001', 'name': 'Анна Ким', 'department': 'Продажи', 'webrtc': false},
    {'number': '1002', 'name': 'Борис Ли', 'department': 'Продажи', 'webrtc': true},
    {'number': '1003', 'name': 'Это я', 'department': 'Продажи', 'webrtc': true},
    {'number': '1010', 'name': 'Склад', 'department': '', 'webrtc': false},
    {'number': '1020', 'name': 'Вера Пак', 'department': 'Бухгалтерия', 'webrtc': true},
  ],
  'features': {'conference': '*3', 'conference_digits': 6, 'record': record},
});

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(SadoApp)));

/// Запускает приложение с настоящей учётной записью и справочником, который отвечает [reply].
Future<DemoEngine> _start(WidgetTester tester, {DirectoryReply? reply, Map<String, Object> saved = const {}}) async {
  directoryOnStart = reply;
  addTearDown(() => directoryOnStart = null);
  final engine = DemoEngine();
  await pumpApp(tester, saved: {...realAccount, ...saved}, savedPassword: 'secret', engine: (_) => engine);
  await tester.pump(const Duration(milliseconds: 100));
  return engine;
}

Future<void> _openContacts(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab.2')));
  await tester.pumpAndSettle();
}

void main() {
  group('разбор ответа сервера', () {
    test('обычный ответ: записи по порядку, без самого себя, с возможностями', () {
      final data = parseDirectory(
        _body(record: '*1'),
        self: '1003',
        etag: '"v1"',
      )!;
      expect([for (final e in data.entries) e.number], ['1001', '1002', '1010', '1020']);
      expect(data.entries.first.name, 'Анна Ким');
      expect(data.entries.first.department, 'Продажи');
      expect(data.etag, '"v1"');
      expect(data.features.conferencePrefix, '*3');
      expect(data.features.conferenceDigits, 6);
      expect(data.features.recordCode, '*1');
    });

    test('запись этому номеру не разрешена — кода записи нет', () {
      expect(parseDirectory(_body(), self: '1003')!.features.recordCode, isNull);
    });

    test('не справочник — null', () {
      expect(parseDirectory('<html>404</html>', self: '1003'), isNull);
      expect(parseDirectory('[]', self: '1003'), isNull);
      expect(parseDirectory('{"entries": "нет"}', self: '1003'), isNull);
    });

    test('кривые записи пропускаются, длинные строки обрезаются, повторы не берутся', () {
      final body = jsonEncode({
        'entries': [
          {'number': '1001', 'name': 'Анна'},
          {'number': '1001', 'name': 'Анна ещё раз'},
          {'number': '', 'name': 'Без номера'},
          {'number': '1002', 'name': ''},
          'мусор',
          {'number': 1005, 'name': 'Номер числом'},
          {'number': '1006', 'name': 'Я' * 500, 'department': 7},
        ],
      });
      final data = parseDirectory(body, self: '1003')!;
      expect([for (final e in data.entries) e.number], ['1001', '1006']);
      expect(data.entries.last.name.length, 80);
      expect(data.entries.last.department, '');
      expect(data.features, PbxFeatures.none);
    });

    test('служебные коды принимаются, только если похожи на коды', () {
      expect(featuresFrom({'conference': '*3', 'conference_digits': 6, 'record': '*1'}).canConference, isTrue);
      // Не код, а что-то постороннее — набирать такое приложение не станет.
      expect(featuresFrom({'conference': '+79001234567@evil.example'}).canConference, isFalse);
      expect(featuresFrom({'conference': '*3', 'record': 'sip:spy@evil.example'}).recordCode, isNull);
      expect(featuresFrom({'conference': '*3', 'conference_digits': 99}).conferenceDigits, 6);
      expect(featuresFrom(null), PbxFeatures.none);
      expect(featuresFrom('*3'), PbxFeatures.none);
    });

    test('адрес справочника: тот же сервер, всегда HTTPS; у учебной записи его нет', () {
      expect(
        directoryUrl(const Account(server: 'pbx.example.com', number: '1003')).toString(),
        'https://pbx.example.com/api/v1/directory',
      );
      expect(
        directoryUrl(const Account(server: 'wss://pbx.example.com:8089/ws', number: '1003')).toString(),
        'https://pbx.example.com/api/v1/directory',
      );
      // Даже если звонки идут без шифрования, пароль в справочник — только по HTTPS.
      expect(
        directoryUrl(const Account(server: 'ws://192.0.2.10:5066', number: '1003')).toString(),
        'https://192.0.2.10/api/v1/directory',
      );
      expect(directoryUrl(const Account(server: 'demo', number: '1003')), isNull);
    });
  });

  testWidgets('справочник есть: отделы в контактах, свои контакты сверху, себя и повторов нет', (tester) async {
    await _start(
      tester,
      reply: DirectoryLoaded(_body(), '"v1"'),
      saved: {
        'contacts': jsonEncode([
          {'name': 'Боря (мой)', 'number': '1002'},
          {'name': 'Поставщик', 'number': '+998901234567'},
        ]),
      },
    );
    // Пароль отправлен только после пробы без входа, и ровно один раз.
    expect(directory.probes, 1);
    expect(directory.fetches, [(number: '1003', password: 'secret', etag: null)]);

    await _openContacts(tester);
    expect(find.text('Свои контакты'), findsOneWidget);
    expect(find.text('Продажи'), findsOneWidget);
    expect(find.text('Бухгалтерия'), findsOneWidget);
    // Номер без отдела — под общим заголовком.
    expect(find.text('Сотрудники'), findsOneWidget);
    expect(find.text('Анна Ким'), findsOneWidget);
    expect(find.text('Вера Пак'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    // 1002 уже есть в своих контактах под своим именем — из справочника его не повторяем; себя не показываем.
    expect(find.text('Боря (мой)'), findsOneWidget);
    expect(find.text('Борис Ли'), findsNothing);
    expect(find.text('Это я'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('справочник сохраняется и показывается без сети; с меткой версии список не качается заново', (
    tester,
  ) async {
    await _start(tester, reply: DirectoryLoaded(_body(), '"v1"'));
    final saved = (await SharedPreferences.getInstance()).getString('directory.cache');
    expect(saved, isNotNull);

    // Следующий запуск: сервер недоступен, но список виден из сохранённого.
    directoryOnStart = const DirectoryUnreachable();
    final engine = DemoEngine();
    await pumpApp(
      tester,
      saved: {...realAccount, 'directory.cache': saved!, 'directory.known': 'sado.test'},
      savedPassword: 'secret',
      engine: (_) => engine,
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Сервер уже известен как справочник — пробы нет; метка версии отправлена.
    expect(directory.probes, 0);
    expect(directory.fetches.single.etag, '"v1"');
    await _openContacts(tester);
    expect(find.text('Анна Ким'), findsOneWidget);
    expect(_container(tester).read(pbxFeaturesProvider).canConference, isTrue);
  });

  testWidgets('на сервере нет справочника: пароль туда не отправляется, сутки не спрашиваем', (tester) async {
    await _start(tester);
    expect(directory.probes, 1);
    expect(directory.fetches, isEmpty);
    expect(_container(tester).read(directoryProvider), isNull);
    expect(_container(tester).read(pbxFeaturesProvider), PbxFeatures.none);

    // Открыли контакты — повторной пробы нет.
    await _openContacts(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(directory.probes, 1);
    expect(directory.fetches, isEmpty);
  });

  testWidgets('сеть недоступна при пробе: пароль не отправлен, позже приложение пробует снова', (tester) async {
    directoryOfflineOnStart = true;
    addTearDown(() => directoryOfflineOnStart = false);
    await _start(tester, reply: DirectoryLoaded(_body(), '"v1"'));
    expect(directory.probes, 1);
    expect(directory.fetches, isEmpty);
    // «Не знаю» — не то же, что «справочника нет»: суточная пауза не начинается.
    expect((await SharedPreferences.getInstance()).getInt('directory.absentAt'), isNull);

    // Сеть появилась: при следующем обращении (не раньше чем через десять минут) приложение пробует снова.
    directory.isDirectory = true;
    await tester.pump(const Duration(minutes: 11));
    await _container(tester).read(directoryProvider.notifier).refresh();
    await tester.pump(const Duration(milliseconds: 100));
    expect(directory.probes, 2);
    expect(directory.fetches, hasLength(1));
    expect(_container(tester).read(directoryProvider)!.entries, hasLength(4));
  });

  testWidgets('сервер не принял пароль: больше не спрашиваем — за повторы он блокирует адрес', (tester) async {
    await _start(tester, reply: const DirectoryDenied());
    expect(directory.fetches, hasLength(1));
    await _openContacts(tester);
    await tester.pump(const Duration(minutes: 30));
    _container(tester).read(directoryProvider.notifier).refresh(force: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(directory.fetches, hasLength(1));
  });

  testWidgets('сервер заблокировал адрес: молчим четверть часа, потом спрашиваем снова', (tester) async {
    await _start(tester, reply: const DirectoryBlocked());
    expect(directory.fetches, hasLength(1));
    await tester.pump(const Duration(minutes: 5));
    await _container(tester).read(directoryProvider.notifier).refresh(force: true);
    expect(directory.fetches, hasLength(1));

    directory.reply = DirectoryLoaded(_body(), '"v1"');
    await tester.pump(const Duration(minutes: 11));
    await _container(tester).read(directoryProvider.notifier).refresh(force: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(directory.fetches, hasLength(2));
    expect(_container(tester).read(directoryProvider)!.entries, hasLength(4));
  });

  testWidgets('имя коллеги из справочника видно на экране звонка', (tester) async {
    final engine = await _start(tester, reply: DirectoryLoaded(_body(), '"v1"'));
    engine.simulateIncoming(number: '1020');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Вера Пак'), findsWidgets);
    engine.hangUp();
    await tester.pumpAndSettle();
  });

  testWidgets('АТС сообщила про конференции — при двух разговорах появляется «Объединить»', (tester) async {
    final engine = await _start(tester, reply: DirectoryLoaded(_body(), '"v1"'));
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    await callAndAnswer(tester, '1002');
    engine.simulateIncoming(number: '1020');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('call.waiting.accept')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call.merge')), findsOneWidget);
    await tester.tap(find.byKey(const Key('call.merge')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(engine.conferenceRoom, matches(RegExp(r'^\*3\d{6}$')));
    engine.hangUp();
    await tester.pumpAndSettle();
  });

  testWidgets('выход из учётной записи стирает справочник с телефона', (tester) async {
    await _start(tester, reply: DirectoryLoaded(_body(), '"v1"'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('directory.cache'), isNotNull);
    await _container(tester).read(sessionProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(prefs.getString('directory.cache'), isNull);
    expect(prefs.getString('directory.known'), isNull);
    expect(_container(tester).read(directoryProvider), isNull);
    expect(_container(tester).read(pbxFeaturesProvider), PbxFeatures.none);
  });

  testWidgets('учебная запись: на сервер за справочником не ходим вовсе', (tester) async {
    directoryOnStart = DirectoryLoaded(_body(), '"v1"');
    addTearDown(() => directoryOnStart = null);
    await pumpApp(tester, saved: demoAccount);
    await _openContacts(tester);
    expect(directory.probes, 0);
    expect(directory.fetches, isEmpty);
    // Пользуемся провайдером звонков, чтобы убедиться, что приложение живо.
    expect(_container(tester).read(callProvider), isNull);
  });
}

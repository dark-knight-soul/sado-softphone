import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/l10n/strings.dart';
import 'package:sado/platform/call_keeper.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/state/session.dart';
import 'package:sado/state/setup_link.dart';

import 'app_test.dart';

/// Текст в поле формы входа.
String _field(WidgetTester tester, String key) => tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(SadoApp)));

/// Подменяет буфер обмена: Clipboard.getData вернёт [text] (null — буфер пуст).
void _mockClipboard(WidgetTester tester, String? text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return text == null ? null : {'text': text};
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

const _full = 'sado://login?server=wss%3A%2F%2Fpbx.example.com%3A8089%2Fws&number=1004&password=p%2Bss%20w%25rd';

void main() {
  tearDown(() => pendingSetupOnStart = null);

  group('parseSetupLink', () {
    test('минимальная ссылка: сервер и номер', () {
      final link = parseSetupLink('sado://login?server=pbx.example.com&number=1003')!;
      expect(link.server, 'pbx.example.com');
      expect(link.number, '1003');
      expect(link.password, isNull);
    });

    test('с паролем и полным адресом wss://, значения раскодированы', () {
      final link = parseSetupLink(_full)!;
      expect(link.server, 'wss://pbx.example.com:8089/ws');
      expect(link.number, '1004');
      // «+» остаётся плюсом, %20 — пробел, %25 — знак процента.
      expect(link.password, 'p+ss w%rd');
    });

    test('регистр схемы и имени не важен, лишние параметры не мешают', () {
      final link = parseSetupLink('SADO://Login?x=1&server=WSS://pbx.test&number=7&utm=qr')!;
      expect(link.server, 'wss://pbx.test');
      expect(link.number, '7');
    });

    test('имя сервера с портом и путём, ws:// тоже допустим', () {
      expect(parseSetupLink('sado://login?server=pbx.test:8089/ws&number=1')!.server, 'pbx.test:8089/ws');
      expect(parseSetupLink('sado://login?server=ws://192.0.2.10:8080/ws&number=1')!.server, 'ws://192.0.2.10:8080/ws');
    });

    test('без сервера или номера ссылка недействительна', () {
      expect(parseSetupLink('sado://login?number=1003'), isNull);
      expect(parseSetupLink('sado://login?server=pbx.test'), isNull);
      expect(parseSetupLink('sado://login?server=&number=1003'), isNull);
      expect(parseSetupLink('sado://login?server=%20%20&number=1003'), isNull);
      expect(parseSetupLink('sado://login'), isNull);
    });

    test('чужая схема или чужое имя — не наша ссылка', () {
      expect(parseSetupLink('https://login?server=pbx.test&number=1'), isNull);
      expect(parseSetupLink('sado://dial?server=pbx.test&number=1'), isNull);
      expect(parseSetupLink('sado:login?server=pbx.test&number=1'), isNull);
      expect(parseSetupLink(''), isNull);
      expect(parseSetupLink('просто текст'), isNull);
    });

    test('сервер с другой схемой отвергается', () {
      for (final server in [
        'http://pbx.test',
        'https://pbx.test',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'wss://',
        'ws:///ws',
        '/ws',
      ]) {
        final raw = 'sado://login?server=${Uri.encodeComponent(server)}&number=1';
        expect(parseSetupLink(raw), isNull, reason: server);
      }
    });

    test('слишком длинные значения отвергаются', () {
      final server = 'a' * 201;
      expect(parseSetupLink('sado://login?server=$server&number=1'), isNull);
      expect(parseSetupLink('sado://login?server=${'a' * 200}&number=1'), isNotNull);
      expect(parseSetupLink('sado://login?server=pbx.test&number=${'1' * 33}'), isNull);
      expect(parseSetupLink('sado://login?server=pbx.test&number=${'1' * 32}'), isNotNull);
      expect(parseSetupLink('sado://login?server=pbx.test&number=1&password=${'p' * 129}'), isNull);
      expect(parseSetupLink('sado://login?server=pbx.test&number=1&password=${'p' * 128}'), isNotNull);
      // Вся ссылка длиннее 1000 знаков — даже не разбираем.
      expect(parseSetupLink('sado://login?server=pbx.test&number=1&x=${'y' * 1000}'), isNull);
    });

    test('управляющие знаки и пробелы отвергаются', () {
      expect(parseSetupLink('sado://login?server=pbx.test%0Aevil&number=1'), isNull);
      expect(parseSetupLink('sado://login?server=pbx%20test&number=1'), isNull);
      expect(parseSetupLink('sado://login?server=pbx.test&number=1&password=a%00b'), isNull);
      expect(parseSetupLink('sado://login?server=pbx.test&number=1&password=a%0Db'), isNull);
      // Испорченное %-кодирование и повтор поля — тоже мимо.
      expect(parseSetupLink('sado://login?server=pbx.test&number=1&password=%E0%A4'), isNull);
      expect(parseSetupLink('sado://login?server=a.test&server=b.test&number=1'), isNull);
    });

    test('номер очищается так же, как при наборе', () {
      const raw = '100@evil.example;x=1';
      final link = parseSetupLink('sado://login?server=pbx.test&number=${Uri.encodeComponent(raw)}')!;
      expect(link.number, dialTarget(raw));
      expect(parseSetupLink('sado://login?server=pbx.test&number=%3C%3E'), isNull, reason: 'после очистки пусто');
    });

    test('пароль не печатается вместе с объектом', () {
      expect(parseSetupLink(_full).toString(), isNot(contains('p+ss')));
    });
  });

  testWidgets('ссылка при запуске без входа заполняет форму, но не входит', (tester) async {
    pendingSetupOnStart = _full;
    await pumpApp(tester, saved: {'lang': 'ru'});
    expect(_field(tester, 'login.server'), 'wss://pbx.example.com:8089/ws');
    expect(_field(tester, 'login.number'), '1004');
    expect(_field(tester, 'login.password'), 'p+ss w%rd');
    expect(find.byKey(const Key('login.fromLink')), findsOneWidget);
    expect(find.text('Данные получены по ссылке. Проверьте адрес сервера и нажмите «Войти».'), findsOneWidget);
    expect(find.byKey(const Key('login.insecure')), findsNothing);
    // Вход не выполнен: кнопка на месте, учётной записи нет, запрос стёрт.
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
    expect(_container(tester).read(sessionProvider), isNull);
    expect(_container(tester).read(setupRequestProvider), isNull);
  });

  testWidgets('ссылка при открытом экране входа заполняет форму', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    expect(find.byKey(const Key('login.fromLink')), findsNothing);
    keeper.onSetupRequest!('sado://login?server=pbx.test&number=1005');
    await tester.pumpAndSettle();
    expect(_field(tester, 'login.server'), 'pbx.test');
    expect(_field(tester, 'login.number'), '1005');
    expect(_field(tester, 'login.password'), '');
    expect(find.byKey(const Key('login.fromLink')), findsOneWidget);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
    expect(_container(tester).read(sessionProvider), isNull);
    expect(_container(tester).read(setupRequestProvider), isNull);
  });

  test('ответ сканера: понятный разбирается, непонятный считается «сканера нет»', () {
    expect(QrScan.fromMap({'status': 'ok', 'text': 'abc'}).status, QrScanStatus.ok);
    expect(QrScan.fromMap({'status': 'ok', 'text': 'abc'}).text, 'abc');
    // «Прочитано», но текста нет — считаем, что человек ничего не отсканировал.
    expect(QrScan.fromMap({'status': 'ok', 'text': ''}).status, QrScanStatus.cancelled);
    expect(QrScan.fromMap({'status': 'ok'}).status, QrScanStatus.cancelled);
    expect(QrScan.fromMap({'status': 'cancelled'}).status, QrScanStatus.cancelled);
    expect(QrScan.fromMap({'status': 'denied'}).status, QrScanStatus.denied);
    expect(QrScan.fromMap(null).status, QrScanStatus.unavailable);
    expect(QrScan.fromMap('ok').status, QrScanStatus.unavailable);
    expect(QrScan.fromMap({'status': 'что-то новое'}).status, QrScanStatus.unavailable);
  });

  Future<void> scan(WidgetTester tester, QrScan answer) async {
    keeper.scanAnswer = answer;
    await tester.ensureVisible(find.byKey(const Key('login.qr')));
    await tester.tap(find.byKey(const Key('login.qr')));
    await tester.pumpAndSettle();
  }

  testWidgets('сканер: QR-код со ссылкой настройки заполняет форму, но не входит', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    await scan(tester, const QrScan(QrScanStatus.ok, _full));
    // Сканеру переданы подсказка и надпись кнопки на языке приложения.
    expect(keeper.log, contains('scan: Наведите камеру на QR-код от администратора | Отмена'));
    expect(_field(tester, 'login.server'), 'wss://pbx.example.com:8089/ws');
    expect(_field(tester, 'login.number'), '1004');
    expect(_field(tester, 'login.password'), 'p+ss w%rd');
    expect(find.byKey(const Key('login.fromLink')), findsOneWidget);
    expect(find.byKey(const Key('login.submit')), findsOneWidget);
    expect(_container(tester).read(sessionProvider), isNull);
  });

  testWidgets('сканер: посторонний QR-код ничего не заполняет и объясняет почему', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    for (final text in [
      'https://example.com/promo',
      'sado://login?server=http://evil.test&number=1',
      'WIFI:S:office;;',
    ]) {
      await scan(tester, QrScan(QrScanStatus.ok, text));
      expect(find.text('В этом QR-коде нет ссылки настройки SADO'), findsOneWidget, reason: text);
      expect(_field(tester, 'login.server'), '', reason: text);
      expect(find.byKey(const Key('login.fromLink')), findsNothing, reason: text);
    }
  });

  testWidgets('сканер: отказ в камере, отмена и отсутствие сканера', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    await scan(tester, const QrScan(QrScanStatus.denied));
    expect(find.textContaining('Нет доступа к камере'), findsOneWidget);

    // Человек просто закрыл сканер — ничего не говорим и не меняем.
    ScaffoldMessenger.of(tester.element(find.byKey(const Key('login.qr')))).clearSnackBars();
    await tester.pumpAndSettle();
    await scan(tester, const QrScan(QrScanStatus.cancelled));
    expect(find.byType(SnackBar), findsNothing);
    expect(_field(tester, 'login.server'), '');

    // Сканера нет (не Android) — прежняя подсказка про обычную камеру телефона.
    await scan(tester, const QrScan(QrScanStatus.unavailable));
    expect(find.textContaining('Наведите камеру телефона на QR-код'), findsOneWidget);
  });

  testWidgets('недействительная ссылка ничего не меняет', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    keeper.onSetupRequest!('sado://login?server=http://evil.test&number=1');
    await tester.pumpAndSettle();
    expect(_field(tester, 'login.server'), '');
    expect(find.byKey(const Key('login.fromLink')), findsNothing);
  });

  testWidgets('адрес ws:// из ссылки — показано предупреждение', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    keeper.onSetupRequest!('sado://login?server=ws%3A%2F%2F192.0.2.10%3A8080%2Fws&number=1003');
    await tester.pumpAndSettle();
    expect(_field(tester, 'login.server'), 'ws://192.0.2.10:8080/ws');
    expect(find.byKey(const Key('login.insecure')), findsOneWidget);
  });

  testWidgets('после входа ссылка не меняет учётную запись', (tester) async {
    await pumpApp(tester, saved: demoAccount);
    final before = _container(tester).read(sessionProvider)!;
    keeper.onSetupRequest!('sado://login?server=other.test&number=2000&password=x');
    await tester.pumpAndSettle();
    expect(find.text('Вы уже вошли. Чтобы применить ссылку, сначала выйдите из учётной записи.'), findsOneWidget);
    final after = _container(tester).read(sessionProvider)!;
    expect(after.server, before.server);
    expect(after.number, before.number);
    expect(_container(tester).read(setupRequestProvider), isNull);
  });

  testWidgets('ссылка при запуске после входа — только сообщение', (tester) async {
    pendingSetupOnStart = 'sado://login?server=other.test&number=2000';
    await pumpApp(tester, saved: demoAccount);
    expect(find.text('Вы уже вошли. Чтобы применить ссылку, сначала выйдите из учётной записи.'), findsOneWidget);
    expect(_container(tester).read(sessionProvider)!.number, '1003');
    expect(_container(tester).read(setupRequestProvider), isNull);
  });

  testWidgets('«Вставить ссылку настройки» берёт ссылку из буфера обмена', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    _mockClipboard(tester, '  sado://login?server=pbx.test&number=1006&password=secret\n');
    await tester.ensureVisible(find.byKey(const Key('login.paste')));
    await tester.tap(find.byKey(const Key('login.paste')));
    await tester.pumpAndSettle();
    expect(_field(tester, 'login.server'), 'pbx.test');
    expect(_field(tester, 'login.number'), '1006');
    expect(_field(tester, 'login.password'), 'secret');
    expect(find.byKey(const Key('login.fromLink')), findsOneWidget);
    expect(_container(tester).read(sessionProvider), isNull);
  });

  testWidgets('в буфере обмена не ссылка — сообщение, поля не тронуты', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    _mockClipboard(tester, 'какой-то текст');
    await tester.ensureVisible(find.byKey(const Key('login.paste')));
    await tester.tap(find.byKey(const Key('login.paste')));
    await tester.pumpAndSettle();
    expect(find.text('В буфере обмена нет ссылки настройки'), findsOneWidget);
    expect(_field(tester, 'login.server'), '');
    expect(find.byKey(const Key('login.fromLink')), findsNothing);
  });

  testWidgets('пустой буфер обмена — то же сообщение', (tester) async {
    await pumpApp(tester, saved: {'lang': 'ru'});
    _mockClipboard(tester, null);
    await tester.ensureVisible(find.byKey(const Key('login.paste')));
    await tester.tap(find.byKey(const Key('login.paste')));
    await tester.pumpAndSettle();
    expect(find.text('В буфере обмена нет ссылки настройки'), findsOneWidget);
  });

  testWidgets('экран входа со ссылкой помещается на маленьком телефоне на всех языках', (tester) async {
    for (final lang in S.languageNames.keys) {
      // ws:// — чтобы на экране было и предупреждение: самый длинный вариант формы.
      pendingSetupOnStart = 'sado://login?server=ws%3A%2F%2Fpbx.example.com%2Fws&number=1003&password=x';
      await pumpApp(tester, saved: {'lang': lang}, size: const Size(320, 568));
      expect(tester.takeException(), isNull, reason: 'язык $lang');
      expect(find.byKey(const Key('login.fromLink')), findsOneWidget, reason: 'язык $lang');
      expect(find.byKey(const Key('login.insecure')), findsOneWidget, reason: 'язык $lang');
      expect(find.byKey(const Key('login.paste')), findsOneWidget, reason: 'язык $lang');
    }
  });
}

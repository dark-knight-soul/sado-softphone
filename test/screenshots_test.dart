// Снимки экранов для README. В обычном прогоне тестов пропускается.
//
// Запуск (картинки ложатся в build/shots, оттуда их собирает tool/make_screens.py):
//
//   flutter test --dart-define=SADO_SHOTS=true test/screenshots_test.dart
//
// Снимки делаются из самого приложения с вымышленными контактами и историей — без телефона
// и без чьих-либо настоящих данных. Шрифт — Roboto из комплекта Flutter (как на «чистом» Android).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/platform/call_keeper.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/call.dart';
import 'package:sado/state/password_store.dart';
import 'package:sado/state/session.dart';
import 'package:sado/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _enabled = bool.fromEnvironment('SADO_SHOTS');

/// Язык снимков. Для README — английский; другой язык задаётся так: --dart-define=SADO_SHOTS_LANG=de
/// (удобно глазами проверить, не обрезаются ли надписи перевода).
const _lang = String.fromEnvironment('SADO_SHOTS_LANG', defaultValue: 'en');

/// Размер экрана обычного телефона в точках и отступы под строку состояния и полоску жестов.
const _size = Size(394, 853);
const _top = 38.0;
const _bottom = 22.0;

final _shotKey = GlobalKey();

/// Сторож, который «умеет» менять значок — чтобы в настройках был виден ряд значков.
class _ShotKeeper extends NoopCallKeeper {
  @override
  Future<String?> appIcon() async => 'sado';
}

/// Вымышленные контакты и история (имена латиницей — снимки идут в английское описание).
String _contacts() => jsonEncode([
  {'name': 'Aziz Karimov', 'number': '1002'},
  {'name': 'Dilnoza Yusupova', 'number': '1004'},
  {'name': 'Malika Tosheva', 'number': '1006'},
  {'name': 'Sherzod Rakhimov', 'number': '1005'},
  {'name': 'Warehouse', 'number': '1010'},
  {'name': 'Accounting', 'number': '1020'},
  {'name': 'Front desk', 'number': '1030'},
]);

String _history() {
  final now = DateTime.now();
  int ago({int minutes = 0, int days = 0}) =>
      now.subtract(Duration(minutes: minutes, days: days)).millisecondsSinceEpoch;
  return jsonEncode([
    {'name': 'Aziz Karimov', 'number': '1002', 'kind': 'outgoing', 'seconds': 240, 'at': ago(minutes: 4)},
    {'name': 'Dilnoza Yusupova', 'number': '1004', 'kind': 'missed', 'seconds': 0, 'at': ago(minutes: 31)},
    {'name': 'Warehouse', 'number': '1010', 'kind': 'incoming', 'seconds': 75, 'at': ago(minutes: 58)},
    {'number': '905550122', 'kind': 'incoming', 'seconds': 720, 'at': ago(days: 1)},
    {'name': 'Accounting', 'number': '1020', 'kind': 'outgoing', 'seconds': 130, 'at': ago(days: 1, minutes: 50)},
    {'name': 'Sherzod Rakhimov', 'number': '1005', 'kind': 'missed', 'seconds': 0, 'at': ago(days: 3)},
    {'name': 'Malika Tosheva', 'number': '1006', 'kind': 'outgoing', 'seconds': 45, 'at': ago(days: 4)},
  ]);
}

Future<void> _loadFonts() async {
  // Шрифты лежат в комплекте Flutter; где он установлен, говорит переменная FLUTTER_ROOT.
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\dev\flutter';
  final dir = '$root\\bin\\cache\\artifacts\\material_fonts';
  // «FlutterTest» — шрифт-заглушка, которым тесты рисуют текст без явно заданного шрифта (например, подписи
  // на кнопках). Подменяем и его, иначе такие подписи выходят сплошными прямоугольниками.
  for (final family in ['Roboto', 'FlutterTest']) {
    final loader = FontLoader(family);
    for (final name in ['roboto-light', 'roboto-regular', 'roboto-medium', 'roboto-bold', 'roboto-black']) {
      final bytes = File('$dir\\$name.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  // Шрифт значков в тестах сам не подгружается — без него вместо значков пустые квадраты.
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(File('$dir\\materialicons-regular.otf').readAsBytesSync().buffer)));
  await icons.load();
}

Future<void> _start(WidgetTester tester, {required String style, required String theme, String answer = 'auto'}) async {
  SharedPreferences.setMockInitialValues({
    'account.server': 'pbx.example.com',
    'account.number': '1003',
    'lang': _lang,
    'style': style,
    'themeMode': theme,
    'answerMode': answer,
    'iconSet': 'filled',
    'contacts': _contacts(),
    'history': _history(),
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: _top, bottom: _bottom);
  tester.view.viewPadding = const FakeViewPadding(top: _top, bottom: _bottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: ProviderScope(
        key: UniqueKey(),
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          passwordStoreProvider.overrideWithValue(MemoryPasswordStore('x')),
          engineFactoryProvider.overrideWithValue((_) => DemoEngine()),
          callKeeperProvider.overrideWithValue(_ShotKeeper()),
        ],
        child: const SadoApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Сохраняет то, что сейчас на экране, в build/shots/<имя>.png в тройном разрешении.
Future<void> _shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/shots/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _tab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('tab.$index')));
  await tester.pumpAndSettle();
}

Future<void> _dial(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Key('key.$d')));
  }
  await tester.pump();
  // Кнопка «стереть» появляется плавно, а след от нажатия на клавише гаснет — ждём, пока всё успокоится.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _call(WidgetTester tester, String digits) async {
  await _dial(tester, digits);
  await tester.tap(find.byKey(const Key('dialer.call')));
  await tester.pump(const Duration(seconds: 3));
  await _talk(tester);
}

/// Даёт разговору «пройти» несколько настоящих секунд, чтобы таймер на снимке показывал не «00:00»
/// (таймер смотрит на настоящие часы, а не на время теста).
Future<void> _talk(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 7)));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _ring(WidgetTester tester) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(SadoApp)));
  container.read(callProvider.notifier).simulateIncoming(number: '1004', name: 'Dilnoza Yusupova');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('набор номера в четырёх стилях', (tester) async {
    for (final (style, theme) in [('emerald', 'light'), ('night', 'dark'), ('air', 'light'), ('sunset', 'light')]) {
      await _start(tester, style: style, theme: theme);
      await _dial(tester, '1002');
      await _shot(tester, 'dial-$style');
    }
  }, skip: !_enabled);

  testWidgets('«Материал»: главная, набор, входящий, разговор, перевод', (tester) async {
    await _start(tester, style: 'material', theme: 'dark');
    await _tab(tester, 1);
    await _shot(tester, 'material-home');
    await _ring(tester);
    await _shot(tester, 'material-incoming');

    await _start(tester, style: 'material', theme: 'light');
    await _dial(tester, '1002');
    await _shot(tester, 'material-dial');
    await tester.tap(find.byKey(const Key('dialer.call')));
    await tester.pump(const Duration(seconds: 3));
    await _talk(tester);
    await _shot(tester, 'material-call');
    await tester.tap(find.byKey(const Key('call.more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('call.transfer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (final d in '1020'.split('')) {
      await tester.tap(find.byKey(Key('transfer.key.$d')));
    }
    await tester.pump();
    // Кнопка «Перевести» плавно «включается», след от нажатия на клавише гаснет — ждём.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, 'material-transfer');
  }, skip: !_enabled);

  testWidgets('«Купертино»: входящий, разговор, клавиши, история', (tester) async {
    await _start(tester, style: 'cupertino', theme: 'light');
    await _tab(tester, 1);
    await _shot(tester, 'cupertino-history');
    await _ring(tester);
    await _shot(tester, 'cupertino-incoming');

    await _start(tester, style: 'cupertino', theme: 'light');
    await _tab(tester, 0);
    await _call(tester, '1002');
    await _shot(tester, 'cupertino-call');
    await tester.tap(find.byKey(const Key('call.keypad')));
    await tester.pump();
    await _shot(tester, 'cupertino-keypad');
  }, skip: !_enabled);

  testWidgets('остальные экраны: контакты, настройки, разговор, входящий', (tester) async {
    await _start(tester, style: 'emerald', theme: 'light');
    await _tab(tester, 2);
    await _shot(tester, 'emerald-contacts');
    await _tab(tester, 3);
    await _shot(tester, 'emerald-settings');
    await _tab(tester, 0);
    await _call(tester, '1002');
    await _shot(tester, 'emerald-call');

    await _start(tester, style: 'night', theme: 'dark', answer: 'pill');
    await _ring(tester);
    await _shot(tester, 'night-incoming');

    await _start(tester, style: 'sunset', theme: 'light');
    await _call(tester, '1010');
    await _shot(tester, 'sunset-call');

    await _start(tester, style: 'night', theme: 'dark');
    await _tab(tester, 1);
    await _shot(tester, 'night-history');
  }, skip: !_enabled);
}

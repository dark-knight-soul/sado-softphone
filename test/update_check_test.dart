import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sado/app.dart';
import 'package:sado/platform/call_keeper.dart';
import 'package:sado/sip/demo_engine.dart';
import 'package:sado/state/app_version.dart';
import 'package:sado/state/password_store.dart';
import 'package:sado/state/session.dart';
import 'package:sado/state/settings.dart';
import 'package:sado/state/update_check.dart';
import 'package:sado/theme/sado_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart';

/// Проверка без сети: отвечает заданным итогом и считает, сколько раз её вызвали.
class FakeUpdateChecker implements UpdateChecker {
  FakeUpdateChecker(this.result);

  UpdateResult result;
  int calls = 0;

  /// Если задан — ответ задерживается, пока тест его не завершит (чтобы увидеть крутилку).
  Completer<void>? gate;

  @override
  Future<UpdateResult> check() async {
    calls++;
    await gate?.future;
    return result;
  }
}

/// Как pumpApp из app_test.dart, но вместо настоящей проверки обновлений — [checker].
Future<void> pumpWithChecker(
  WidgetTester tester,
  FakeUpdateChecker checker, {
  Map<String, Object> saved = demoAccount,
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
        passwordStoreProvider.overrideWithValue(MemoryPasswordStore(null)),
        engineFactoryProvider.overrideWithValue((_) => DemoEngine()),
        callKeeperProvider.overrideWithValue(keeper = RecordingKeeper()),
        updateCheckerProvider.overrideWithValue(checker),
      ],
      child: const SadoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Открывает вкладку «Ещё» и докручивает до кнопки проверки.
Future<void> openAbout(WidgetTester tester) async {
  final more = find.byKey(Key('tab.${AppTab.more.index}'));
  // В стиле «Материал» вкладки «Ещё» в меню нет: настройки открываются кнопкой в строке поиска «Главной».
  if (more.evaluate().isEmpty) {
    await tester.tap(find.byKey(Key('tab.${AppTab.history.index}')));
    await tester.pumpAndSettle();
  }
  await tester.tap(more);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const Key('settings.checkUpdates')),
    120,
    scrollable: scrollableOf('settings.list'),
  );
  await tester.pumpAndSettle();
}

/// Элемент отрисовки, на который жалуется ошибка (у переполнения он указан в подробностях).
RenderObject? _renderObjectOf(FlutterErrorDetails details) {
  for (final node in details.informationCollector?.call() ?? const <DiagnosticsNode>[]) {
    final value = node.value;
    if (value is RenderObject) return value;
  }
  return null;
}

/// Лежит ли элемент отрисовки внутри раздела «О приложении».
bool _insideAbout(RenderObject object) {
  final creator = object.debugCreator;
  if (creator is! DebugCreator) return true; // не разобрать — на всякий случай считаем своим
  var inside = creator.element.widget.key == const Key('settings.about');
  creator.element.visitAncestorElements((e) {
    if (e.widget.key == const Key('settings.about')) inside = true;
    return !inside;
  });
  return inside;
}

const _page = 'https://github.com/dark-knight-soul/sado-softphone/releases/tag/v1.2.0';

void main() {
  group('compareVersions', () {
    test('сравнивает по числам, а не как текст', () {
      expect(compareVersions('1.10.0', '1.9.3'), 1);
      expect(compareVersions('1.9.3', '1.10.0'), -1);
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('2.0.0', '1.99.99'), 1);
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.1', '1.2'), 1);
    });

    test('номер сборки и приписки после - не учитываются', () {
      expect(compareVersions('1.2.0+5', '1.2.0'), 0);
      expect(compareVersions('1.2.0-beta', '1.2.0'), 0);
      expect(compareVersions('1.3.0-rc.1', '1.2.9'), 1);
    });

    test('непонятный номер — null', () {
      expect(compareVersions('', '1.0.0'), isNull);
      expect(compareVersions('1..0', '1.0.0'), isNull);
      expect(compareVersions('1.x.0', '1.0.0'), isNull);
      expect(compareVersions('latest', '1.0.0'), isNull);
      expect(compareVersions('1.0.0', '1.0. 1'), isNull);
    });
  });

  group('readLatestRelease', () {
    String body(String tag, String url) => '{"tag_name": "$tag", "html_url": "$url"}';

    test('новее — доступна, с адресом страницы; не новее — последняя', () {
      final newer = readLatestRelease(200, body('v1.2.0', _page), current: '1.0.0');
      expect(newer, isA<UpdateAvailable>());
      expect((newer as UpdateAvailable).version, '1.2.0');
      expect(newer.url, _page);
      expect(readLatestRelease(200, body('v1.0.0', _page), current: '1.0.0'), isA<UpToDate>());
      expect(readLatestRelease(200, body('0.9.0', _page), current: '1.0.0'), isA<UpToDate>());
    });

    test('чужой адрес, плохой ответ или статус — не удалось', () {
      expect(readLatestRelease(200, body('v9.0.0', 'https://evil.example/sado.apk')), isA<UpdateFailed>());
      expect(
        readLatestRelease(200, body('v9.0.0', 'https://github.com/dark-knight-soul/sado-softphone.evil/')),
        isA<UpdateFailed>(),
      );
      expect(readLatestRelease(404, body('v9.0.0', _page)), isA<UpdateFailed>());
      expect(readLatestRelease(200, 'not json'), isA<UpdateFailed>());
      expect(readLatestRelease(200, '[]'), isA<UpdateFailed>());
      expect(readLatestRelease(200, '{"tag_name": 5, "html_url": "$_page"}'), isA<UpdateFailed>());
      expect(readLatestRelease(200, body('nightly', _page)), isA<UpdateFailed>());
    });
  });

  test('константа версии совпадает с pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = line.substring('version:'.length).trim().split('+').first;
    expect(appVersion, version);
  });

  testWidgets('до нажатия запроса нет; после — «последняя версия»', (tester) async {
    final checker = FakeUpdateChecker(const UpToDate())..gate = Completer<void>();
    await pumpWithChecker(tester, checker);
    await openAbout(tester);
    expect(find.text('Версия $appVersion'), findsOneWidget);
    expect(find.text('Проверка обращается к GitHub и выполняется только по нажатию.'), findsOneWidget);
    expect(checker.calls, 0);

    await tester.tap(find.byKey(const Key('settings.checkUpdates')));
    await tester.pump();
    expect(checker.calls, 1);
    expect(find.byKey(const Key('settings.updateProgress')), findsOneWidget);

    checker.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings.updateProgress')), findsNothing);
    expect(find.text('У вас последняя версия'), findsOneWidget);
    expect(find.byKey(const Key('settings.openRelease')), findsNothing);
    expect(checker.calls, 1);
  });

  testWidgets('новая версия: кнопка открывает страницу выпуска', (tester) async {
    final checker = FakeUpdateChecker(const UpdateAvailable('1.2.0', _page));
    await pumpWithChecker(tester, checker);
    await openAbout(tester);
    await tester.tap(find.byKey(const Key('settings.checkUpdates')));
    await tester.pumpAndSettle();
    expect(find.text('Доступна версия 1.2.0'), findsOneWidget);

    final open = find.byKey(const Key('settings.openRelease'));
    await tester.scrollUntilVisible(open, 60, scrollable: scrollableOf('settings.list'));
    expect(find.text('Открыть страницу загрузки'), findsOneWidget);
    await tester.tap(open);
    await tester.pump();
    expect(keeper.log, contains('openUrl: $_page'));
  });

  testWidgets('сбой: «не удалось проверить», ссылки нет', (tester) async {
    final checker = FakeUpdateChecker(const UpdateFailed());
    await pumpWithChecker(tester, checker);
    await openAbout(tester);
    await tester.tap(find.byKey(const Key('settings.checkUpdates')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось проверить. Попробуйте позже.'), findsOneWidget);
    expect(find.byKey(const Key('settings.openRelease')), findsNothing);
    expect(keeper.log.where((l) => l.startsWith('openUrl')), isEmpty);
  });

  testWidgets('раздел помещается на маленьком экране во всех стилях', (tester) async {
    // Ловим сообщения о переполнении сами и засчитываем только те, что случились внутри раздела.
    // В тестовом шрифте каждая буква — квадрат, поэтому строки выше (например, «Ответ на звонок»
    // в «Купертино») переполняются только здесь, а не на телефоне; к этому разделу они не относятся.
    final problems = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final culprit = _renderObjectOf(details);
      if (culprit == null || _insideAbout(culprit)) problems.add(details.exceptionAsString());
    };
    try {
      for (final id in SadoStyleId.values) {
        final checker = FakeUpdateChecker(const UpdateAvailable('1.2.0', _page));
        await pumpWithChecker(tester, checker, saved: {...demoAccount, 'style': id.name}, size: const Size(320, 568));
        await openAbout(tester);
        await tester.tap(find.byKey(const Key('settings.checkUpdates')));
        await tester.pumpAndSettle();
        // Самый высокий вариант раздела — с итогом и кнопкой; докручиваем до самого низа.
        await tester.scrollUntilVisible(
          find.text('Проверка обращается к GitHub и выполняется только по нажатию.'),
          60,
          scrollable: scrollableOf('settings.list'),
        );
        expect(problems, isEmpty, reason: id.name);
        final section = tester.getRect(find.byKey(const Key('settings.about')));
        expect(section.left, greaterThanOrEqualTo(0), reason: id.name);
        expect(section.right, lessThanOrEqualTo(320), reason: id.name);
        expect(tester.getRect(find.byKey(const Key('settings.openRelease'))).right, lessThanOrEqualTo(320));
      }
    } finally {
      FlutterError.onError = original;
    }
  });
}

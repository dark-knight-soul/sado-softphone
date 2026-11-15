import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/presence.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Все экраны рассчитаны на вертикальный телефон; в горизонтальном кнопки ответа не помещались бы.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Настройки читаем до первого кадра, чтобы приложение сразу открылось в нужном стиле и на нужном языке.
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  // Связь с АТС и уведомления запускаем сразу и независимо от экранов: на Android код может работать
  // и без окна — когда его разбудила фоновая служба, а приложение никто не открывал.
  container.listen(presenceProvider, (_, _) {});
  runApp(UncontrolledProviderScope(container: container, child: const SadoApp()));
}

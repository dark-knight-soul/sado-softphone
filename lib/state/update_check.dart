import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_version.dart';
import 'update_check_web.dart' if (dart.library.io) 'update_check_io.dart';

/// Откуда берём сведения о последнем выпуске.
const latestReleaseApi = 'https://api.github.com/repos/dark-knight-soul/sado-softphone/releases/latest';

/// Открывать разрешено только страницы нашего репозитория: ответ сервера — чужие данные,
/// и подменённая ссылка не должна увести человека на посторонний сайт.
const releasePagePrefix = 'https://github.com/dark-knight-soul/sado-softphone/';

/// Итог проверки обновлений.
sealed class UpdateResult {
  const UpdateResult();
}

/// Стоит последняя версия.
class UpToDate extends UpdateResult {
  const UpToDate();
}

/// Вышла версия новее: [version] — её номер, [url] — страница выпуска на GitHub.
class UpdateAvailable extends UpdateResult {
  const UpdateAvailable(this.version, this.url);

  final String version;
  final String url;
}

/// Проверить не удалось (нет сети, сервер ответил не так, ответ не разобрать).
class UpdateFailed extends UpdateResult {
  const UpdateFailed();
}

/// Проверка новых версий. Вызывается только по нажатию кнопки: приложение обещает
/// не ходить ни на какие серверы, кроме АТС, без явной просьбы человека.
abstract class UpdateChecker {
  Future<UpdateResult> check();
}

/// Номер версии «1.2.3» → [1, 2, 3]. Всё после `+` или `-` (номер сборки, «-beta») не учитываем.
/// null — номер не разобрать.
List<int>? parseVersion(String text) {
  var core = text.trim();
  if (core.startsWith('v')) core = core.substring(1);
  final cut = core.indexOf(RegExp('[+-]'));
  if (cut >= 0) core = core.substring(0, cut);
  if (core.isEmpty) return null;
  final parts = <int>[];
  for (final part in core.split('.')) {
    // Только цифры: int.tryParse пропустил бы «-1» или « 1».
    if (!RegExp(r'^\d{1,9}$').hasMatch(part)) return null;
    parts.add(int.parse(part));
  }
  return parts;
}

/// Сравнивает версии по числам: 1.10.0 новее 1.9.3. Недостающие части считаются нулями (1.2 = 1.2.0).
/// Отрицательное — [a] старше, ноль — равны, положительное — [a] новее; null — номер не разобрать.
int? compareVersions(String a, String b) {
  final x = parseVersion(a);
  final y = parseVersion(b);
  if (x == null || y == null) return null;
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// Разбирает ответ GitHub о последнем выпуске. Вынесено отдельно от сетевой части,
/// чтобы проверять разбор тестами без сети.
UpdateResult readLatestRelease(int status, String body, {String current = appVersion}) {
  if (status != 200) return const UpdateFailed();
  try {
    final json = jsonDecode(body);
    if (json is! Map) return const UpdateFailed();
    final tag = json['tag_name'];
    final url = json['html_url'];
    if (tag is! String || url is! String || !url.startsWith(releasePagePrefix)) return const UpdateFailed();
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    final order = compareVersions(version, current);
    if (order == null) return const UpdateFailed();
    return order > 0 ? UpdateAvailable(version, url) : const UpToDate();
  } on FormatException {
    return const UpdateFailed();
  }
}

/// На телефоне — запрос к GitHub, в браузерной версии — заглушка (там кнопки нет).
final updateCheckerProvider = Provider<UpdateChecker>((ref) => createUpdateChecker());

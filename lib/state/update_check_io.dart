import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'update_check.dart';

/// Проверка через GitHub — для телефона и компьютера.
UpdateChecker createUpdateChecker() => _GitHubUpdateChecker();

class _GitHubUpdateChecker implements UpdateChecker {
  /// Дольше ждать нет смысла: человек смотрит на крутилку.
  static const _timeout = Duration(seconds: 8);

  @override
  Future<UpdateResult> check() async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      // Один запрос без повторов: проверка ручная, человек может нажать ещё раз сам.
      return await () async {
        final request = await client.getUrl(Uri.parse(latestReleaseApi));
        request.headers
          ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
          // GitHub отклоняет запросы без User-Agent; лишнего о человеке в нём не сообщаем.
          ..set(HttpHeaders.userAgentHeader, 'SADO');
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        return readLatestRelease(response.statusCode, body);
      }().timeout(_timeout);
    } on Exception {
      // Нет сети, таймаут, обрыв, битая кодировка — для человека всё это «не удалось проверить».
      return const UpdateFailed();
    } finally {
      client.close(force: true);
    }
  }
}

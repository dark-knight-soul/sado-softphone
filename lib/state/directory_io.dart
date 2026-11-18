import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'directory.dart';

/// Запросы к справочнику — для телефона и компьютера.
DirectoryClient createDirectoryClient() => const _HttpDirectoryClient();

class _HttpDirectoryClient implements DirectoryClient {
  const _HttpDirectoryClient();

  static const _timeout = Duration(seconds: 8);

  /// Больше этого ответ не читаем: справочник даже крупной компании намного меньше.
  static const _maxBody = 1024 * 1024;

  /// Один запрос. Перенаправления не выполняем: с ними номер и пароль могли бы уйти на другой адрес.
  Future<T> _get<T>(Uri url, Map<String, String> headers, FutureOr<T> Function(HttpClientResponse) read) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      return await () async {
        final request = await client.getUrl(url);
        request.followRedirects = false;
        request.headers
          ..set(HttpHeaders.acceptHeader, 'application/json')
          ..set(HttpHeaders.userAgentHeader, 'Sado-Mobile/1.0');
        headers.forEach(request.headers.set);
        return await read(await request.close());
      }().timeout(_timeout);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<bool?> probe(Uri url) async {
    try {
      return await _get(url, const {}, (response) async {
        await response.drain<void>();
        // Адрес временно заблокирован сервером (кто-то за тем же выходом в интернет много раз ошибся паролем):
        // тогда и на пробу приходит отказ «слишком часто». Это не значит «справочника нет» — узнаем позже.
        if (response.statusCode == HttpStatus.tooManyRequests) return null;
        if (response.statusCode != HttpStatus.unauthorized) return false;
        return isSadoChallenge(response.headers.value(HttpHeaders.wwwAuthenticateHeader));
      });
    } on Exception {
      return null;
    }
  }

  @override
  Future<DirectoryReply> fetch(Uri url, {required String number, required String password, String? etag}) async {
    // Пароль уходит только по HTTPS: без шифрования его увидел бы любой в той же сети.
    if (url.scheme != 'https') return const DirectoryUnreachable();
    final headers = {
      HttpHeaders.authorizationHeader: 'Basic ${base64Encode(utf8.encode('$number:$password'))}',
      HttpHeaders.ifNoneMatchHeader: ?etag,
    };
    try {
      return await _get<DirectoryReply>(url, headers, (response) async {
        switch (response.statusCode) {
          case HttpStatus.ok:
            final bytes = <int>[];
            await for (final chunk in response) {
              bytes.addAll(chunk);
              if (bytes.length > _maxBody) return const DirectoryAbsent();
            }
            return DirectoryLoaded(utf8.decode(bytes), response.headers.value(HttpHeaders.etagHeader));
          case HttpStatus.notModified:
            await response.drain<void>();
            return const DirectoryNotModified();
          case HttpStatus.unauthorized || HttpStatus.forbidden:
            await response.drain<void>();
            return const DirectoryDenied();
          case HttpStatus.tooManyRequests:
            await response.drain<void>();
            return const DirectoryBlocked();
          default:
            await response.drain<void>();
            return const DirectoryAbsent();
        }
      });
    } on Exception {
      return const DirectoryUnreachable();
    }
  }
}

// Сетевая часть справочника: как приложение опознаёт сервер и чего оно не делает с паролем.
// Сервер здесь учебный, на этом же компьютере.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sado/state/directory.dart';
import 'package:sado/state/directory_io.dart';

void main() {
  late HttpServer server;
  var status = HttpStatus.unauthorized;
  String? challenge;
  String? location;
  final paths = <String>[];
  final authorizations = <String?>[];

  setUp(() async {
    status = HttpStatus.unauthorized;
    challenge = 'Basic realm="sado", charset="UTF-8"';
    location = null;
    paths.clear();
    authorizations.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      paths.add(request.uri.path);
      authorizations.add(request.headers.value(HttpHeaders.authorizationHeader));
      request.response.statusCode = request.uri.path == '/elsewhere' ? HttpStatus.ok : status;
      if (challenge != null) request.response.headers.set(HttpHeaders.wwwAuthenticateHeader, challenge!);
      if (location != null) request.response.headers.set(HttpHeaders.locationHeader, location!);
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Uri url() => Uri.parse('http://127.0.0.1:${server.port}/api/v1/directory');

  test('заголовок сервера: Basic и область «sado», остальные параметры не важны', () {
    expect(isSadoChallenge('Basic realm="sado", charset="UTF-8"'), isTrue);
    expect(isSadoChallenge('Basic realm="sado"'), isTrue);
    expect(isSadoChallenge('basic charset="UTF-8", realm="SADO"'), isTrue);
    expect(isSadoChallenge('Basic realm=sado'), isTrue);
    // Другой сервер на том же адресе — пароль ему отправлять нельзя.
    expect(isSadoChallenge('Basic realm="Router admin"'), isFalse);
    expect(isSadoChallenge('Basic realm="sado-backup"'), isFalse);
    expect(isSadoChallenge('Digest realm="sado", nonce="abc"'), isFalse);
    expect(isSadoChallenge('Bearer'), isFalse);
    expect(isSadoChallenge(''), isFalse);
    expect(isSadoChallenge(null), isFalse);
  });

  test('проба: сервер представился справочником — да; запрос ушёл без номера и пароля', () async {
    expect(await createDirectoryClient().probe(url()), isTrue);
    expect(paths, ['/api/v1/directory']);
    expect(authorizations, [null]);
  });

  test('проба: другой сервер на том же адресе — нет', () async {
    final client = createDirectoryClient();
    challenge = 'Basic realm="Router admin"';
    expect(await client.probe(url()), isFalse);
    challenge = null;
    expect(await client.probe(url()), isFalse);
    status = HttpStatus.notFound;
    expect(await client.probe(url()), isFalse);
    status = HttpStatus.ok;
    expect(await client.probe(url()), isFalse);
  });

  test('проба: адрес временно заблокирован — «не знаю», а не «справочника нет»', () async {
    status = HttpStatus.tooManyRequests;
    challenge = null;
    expect(await createDirectoryClient().probe(url()), isNull);
  });

  test('проба: сервер недоступен — «не знаю»', () async {
    final dead = url();
    await server.close(force: true);
    expect(await createDirectoryClient().probe(dead), isNull);
  });

  test('проба не идёт по перенаправлению', () async {
    status = HttpStatus.found;
    location = 'http://127.0.0.1:${server.port}/elsewhere';
    expect(await createDirectoryClient().probe(url()), isFalse);
    expect(paths, ['/api/v1/directory']);
  });

  test('пароль не отправляется по незащищённому соединению', () async {
    final reply = await createDirectoryClient().fetch(url(), number: '1003', password: 'secret');
    expect(reply, isA<DirectoryUnreachable>());
    // До сервера запрос вообще не дошёл.
    expect(paths, isEmpty);
    expect(authorizations, isEmpty);
  });
}

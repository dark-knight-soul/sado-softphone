// Проверка движка на настоящей АТС (например, Asterisk за Kamailio). По умолчанию пропускается.
//
// Запуск (пароль передаётся переменной окружения — в команду, в код и в git он не попадает):
//
//   SADO_STAND_WS=wss://pbx.example.com/ws SADO_STAND_NUMBER=1003 SADO_STAND_PASSWORD="…" \
//   flutter test test/stand_test.dart
//
// SADO_STAND_DOMAIN нужен, только если домен SIP отличается от адреса подключения
// (например, подключение идёт на 127.0.0.1, а АТС ждёт в адресе своё сетевое имя).
//
// Неверный пароль здесь нарочно не проверяем: на АТС обычно стоит защита от подбора, и лишние отказы
// входа могут заблокировать адрес. Этот случай покрыт учебным сервером в sip_engine_test.dart.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sado/data/demo_data.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/sip/sip_engine.dart';
import 'package:sado/state/account.dart';
import 'package:sado/state/directory.dart';
import 'package:sado/state/directory_io.dart';

void main() {
  final ws = Platform.environment['SADO_STAND_WS'];
  final number = Platform.environment['SADO_STAND_NUMBER'];
  final password = Platform.environment['SADO_STAND_PASSWORD'];
  final missing = ws == null || number == null || password == null;

  test('настоящая АТС: приложение регистрируется', () async {
    final engine = SipEngine();
    addTearDown(engine.dispose);
    final account = Account(server: ws!, number: number!, sipDomain: Platform.environment['SADO_STAND_DOMAIN']);

    final result = await engine.connect(account, password!.trim()).timeout(const Duration(seconds: 20));

    expect(result, LinkStatus.online, reason: 'адрес ${account.wsUrl}, домен ${account.domain}');
  }, skip: missing ? 'АТС не задана: нужны SADO_STAND_WS, SADO_STAND_NUMBER, SADO_STAND_PASSWORD' : null);

  test('настоящая АТС: приходит статус номера (свой номер после регистрации — «свободен»)', () async {
    final engine = SipEngine();
    addTearDown(engine.dispose);
    final account = Account(server: ws!, number: number!, sipDomain: Platform.environment['SADO_STAND_DOMAIN']);
    expect(await engine.connect(account, password!.trim()).timeout(const Duration(seconds: 20)), LinkStatus.online);

    final got = Completer<Presence>();
    engine.presence.addListener(() {
      final status = engine.presence.value[number];
      if (status != null && !got.isCompleted) got.complete(status);
    });
    engine.watchPresence({number});

    // АТС должна поддерживать подписку «presence» и знать статус этого номера (в Asterisk — hint).
    expect(await got.future.timeout(const Duration(seconds: 10)), Presence.free);
  }, skip: missing ? 'АТС не задана: нужны SADO_STAND_WS, SADO_STAND_NUMBER, SADO_STAND_PASSWORD' : null);

  test(
    'настоящая АТС: справочник — проба без входа, список сотрудников, «не изменилось»',
    () async {
      // У стенда сертификат своего удостоверяющего центра. Доверяем ему ТОЛЬКО в этом тесте:
      // само приложение проверяет сертификат как обычно.
      HttpOverrides.global = _TrustStandCertificate();
      addTearDown(() => HttpOverrides.global = null);
      final account = Account(server: ws!, number: number!, sipDomain: Platform.environment['SADO_STAND_DOMAIN']);
      final url = directoryUrl(account)!;
      final client = createDirectoryClient();

      // Без номера и пароля сервер должен представиться справочником SADO — только тогда пароль можно отправлять.
      expect(await client.probe(url), isTrue, reason: 'адрес $url');

      final reply = await client.fetch(url, number: number, password: password!.trim());
      expect(reply, isA<DirectoryLoaded>());
      final loaded = reply as DirectoryLoaded;
      final data = parseDirectory(loaded.body, self: number, etag: loaded.etag)!;
      expect(data.entries, isNotEmpty);
      expect([for (final e in data.entries) e.number], isNot(contains(number)), reason: 'себя в списке нет');
      expect(data.etag, isNotNull);
      final wanted = Platform.environment['SADO_STAND_CONFERENCE'];
      if (wanted != null && wanted.isNotEmpty) expect(data.features.conferencePrefix, wanted);

      // С меткой версии сервер отвечает «не изменилось» и список заново не отдаёт.
      final again = await client.fetch(url, number: number, password: password.trim(), etag: data.etag);
      expect(again, isA<DirectoryNotModified>());
    },
    skip: missing || Platform.environment['SADO_STAND_DIRECTORY'] != '1'
        ? 'справочник не проверяется: нужны настройки АТС и SADO_STAND_DIRECTORY=1'
        : null,
  );
}

/// Принимает любой сертификат — только для проверки на стенде со своим удостоверяющим центром.
class _TrustStandCertificate extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..badCertificateCallback = (certificate, host, port) => true;
}

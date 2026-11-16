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
}

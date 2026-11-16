// Проверка настоящего движка (SipEngine) без АТС: поднимаем на этом же компьютере крошечный
// учебный SIP-сервер поверх WebSocket, который умеет одно — принимать регистрацию с паролем
// по тем же правилам (Digest), что Kamailio и Asterisk.
//
// В этом файле нарочно нет testWidgets: тестовая обвязка Flutter запрещает настоящую сеть,
// а здесь она нужна (только до 127.0.0.1).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/sip/sip_engine.dart';
import 'package:sado/state/account.dart';

const _realm = 'sado-test';
const _nonce = 'f00dfeed';

String _md5(String s) => md5.convert(utf8.encode(s)).toString();

/// Учебный регистратор: без пароля отвечает «401, представьтесь», с верным — «200 OK».
class FakeRegistrar {
  FakeRegistrar._(this._server, this.password);

  final HttpServer _server;
  final String password;

  /// Сколько раз клиент присылал REGISTER (вместе с повтором после 401).
  int registers = 0;
  String? lastUser;
  String? lastUserAgent;

  /// Подписки на статусы: на какой адрес и когда пришли (сервер на них не отвечает — нам важен только темп).
  final subscribes = <(String, DateTime)>[];

  int get port => _server.port;

  static Future<FakeRegistrar> start({required String password}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final registrar = FakeRegistrar._(server, password);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request, protocolSelector: (_) => 'sip');
      socket.listen((data) {
        final text = data is String ? data : utf8.decode(data as List<int>);
        final reply = registrar._handle(text);
        if (reply != null) socket.add(reply);
      });
    });
    return registrar;
  }

  String? _handle(String message) {
    final lines = message.split('\r\n');
    final start = lines.first.split(' ');
    if (start.length >= 3 && start[0] == 'SUBSCRIBE') subscribes.add((start[1], DateTime.now()));
    if (start.length < 3 || start[0] != 'REGISTER') return null;
    registers++;
    final uri = start[1];
    final headers = <String, String>{};
    for (final line in lines.skip(1)) {
      if (line.isEmpty) break;
      final i = line.indexOf(':');
      if (i > 0) headers[line.substring(0, i).trim().toLowerCase()] = line.substring(i + 1).trim();
    }
    lastUserAgent = headers['user-agent'];

    String response(String status, [List<String> extra = const []]) => [
      'SIP/2.0 $status',
      'Via: ${headers['via']}',
      'From: ${headers['from']}',
      'To: ${headers['to']};tag=registrar',
      'Call-ID: ${headers['call-id']}',
      'CSeq: ${headers['cseq']}',
      ...extra,
      'Content-Length: 0',
      '',
      '',
    ].join('\r\n');

    final challenge = ['WWW-Authenticate: Digest realm="$_realm", nonce="$_nonce", algorithm=MD5'];
    final auth = headers['authorization'];
    if (auth == null) return response('401 Unauthorized', challenge);

    String? field(String name) => RegExp('$name="?([^",]+)"?').firstMatch(auth)?.group(1);
    final user = field('username');
    lastUser = user;
    final ha1 = _md5('$user:$_realm:$password');
    final ha2 = _md5('REGISTER:${field('uri') ?? uri}');
    final qop = field('qop');
    final expected = qop == null
        ? _md5('$ha1:$_nonce:$ha2')
        : _md5('$ha1:$_nonce:${field('nc')}:${field('cnonce')}:$qop:$ha2');
    if (field('response') != expected) return response('401 Unauthorized', challenge);
    return response('200 OK', ['Contact: ${headers['contact']}', 'Expires: 300']);
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late FakeRegistrar registrar;
  late SipEngine engine;

  setUp(() async {
    registrar = await FakeRegistrar.start(password: 'right-password');
    engine = SipEngine();
  });

  tearDown(() async {
    engine.dispose();
    await registrar.stop();
  });

  Account account() => Account(server: 'ws://127.0.0.1:${registrar.port}/ws', number: '1007');

  test('верный пароль: приложение регистрируется на АТС и выходит на связь', () async {
    final result = await engine.connect(account(), 'right-password').timeout(const Duration(seconds: 20));

    expect(result, LinkStatus.online);
    expect(engine.link.value, LinkStatus.online);
    expect(registrar.lastUser, '1007');
    // Первый REGISTER без пароля, второй — с ответом на запрос сервера.
    expect(registrar.registers, 2);
    expect(registrar.lastUserAgent, startsWith('Sado-Mobile/'));
  });

  test('подписки на статусы уходят по одной с паузой, а не пачкой', () async {
    expect(await engine.connect(account(), 'right-password').timeout(const Duration(seconds: 20)), LinkStatus.online);

    // Внешний номер и буквы в подписку не попадают вовсе.
    engine.watchPresence({'1001', '1002', '+998901234567', 'reception', '1003'});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(registrar.subscribes, hasLength(1), reason: 'первая подписка уходит сразу, остальные ждут очереди');

    await Future<void>.delayed(SipEngine.subscribeGap * 2.5);
    expect(
      [for (final s in registrar.subscribes) s.$1],
      ['sip:1001@127.0.0.1', 'sip:1002@127.0.0.1', 'sip:1003@127.0.0.1'],
    );
    for (var i = 1; i < registrar.subscribes.length; i++) {
      final gap = registrar.subscribes[i].$2.difference(registrar.subscribes[i - 1].$2);
      // Небольшой запас на неточность таймеров.
      expect(gap, greaterThan(SipEngine.subscribeGap * 0.8), reason: 'между подписками $i-1 и $i');
    }

    // Повторная просьба следить за теми же номерами новых подписок не порождает.
    engine.watchPresence({'1001', '1002', '1003'});
    await Future<void>.delayed(SipEngine.subscribeGap * 1.5);
    expect(registrar.subscribes, hasLength(3));
  });

  test('неверный пароль: отказ с причиной «вход», без бесконечных повторов', () async {
    final result = await engine.connect(account(), 'wrong-password').timeout(const Duration(seconds: 20));

    expect(result.state, LinkState.failed);
    expect(result.error, LinkError.auth);
    final attempts = registrar.registers;
    // После отказа движок останавливается: за перебор пароля сервер может заблокировать адрес.
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(registrar.registers, attempts);
  });

  test('сервер недоступен: отказ с причиной «сеть», а не зависание', () async {
    final dead = Account(server: 'ws://127.0.0.1:${registrar.port + 1}/ws', number: '1007');
    await registrar.stop();

    final result = await engine.connect(dead, 'right-password').timeout(const Duration(seconds: 20));

    expect(result.state, LinkState.failed);
    expect(result.error, LinkError.network);
  });

  test('без связи звонок не начинается, а человек получает причину', () async {
    final failures = <CallFailure>[];
    final sub = engine.failures.listen((e) => failures.add(e.kind));

    engine.dial('1002');
    await Future<void>.delayed(Duration.zero);

    expect(engine.call.value, isNull);
    expect(failures, [CallFailure.offline]);
    await sub.cancel();
  });
}

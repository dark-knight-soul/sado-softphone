// Проверка движка звонков на настоящей АТС — без телефона, в браузере.
//
// Эта страница запускает настоящий SipEngine (тот же, что в приложении) в Chrome с поддельным микрофоном
// и по шагам прогоняет сценарии: регистрация, звонок, удержание, второй звонок, переключение,
// перевод с консультацией, статусы. Звонки «со стороны АТС» по её просьбе делает помощник run.py.
//
// Запуск — см. tool/stand_check/run.py. Проверяется обмен с АТС (SIP), а не звук и не код Android.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:sado/data/demo_data.dart';
import 'package:sado/data/push_info.dart';
import 'package:sado/sip/call_engine.dart';
import 'package:sado/sip/sip_engine.dart';
import 'package:sado/state/account.dart';

const _ws = String.fromEnvironment('SADO_STAND_WS');
const _number = String.fromEnvironment('SADO_STAND_NUMBER');
const _password = String.fromEnvironment('SADO_STAND_PASSWORD');
const _domain = String.fromEnvironment('SADO_STAND_DOMAIN');

/// Номер на АТС, который сам отвечает и держит разговор (эхо-тест).
const _echo = String.fromEnvironment('SADO_STAND_ECHO', defaultValue: '*43');

final _lines = <String>[];
final _shown = ValueNotifier<int>(0);

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url, JSAny? options);

extension type _Response(JSObject _) implements JSObject {
  external JSPromise<JSString> text();
}

/// Запрос к помощнику run.py на том же адресе, откуда открыта страница.
Future<String> _post(String path, [String body = '']) async {
  final options = <String, Object>{'method': 'POST', 'body': body}.jsify();
  final response = await _fetch(path.toJS, options).toDart.timeout(const Duration(seconds: 40));
  return (await response.text().toDart).toDart;
}

/// Просьба к помощнику: «позвони мне», «покажи каналы» и т. п. Возвращает его ответ текстом.
Future<String> _ask(String command) => _post('/cmd/$command');

Future<void> _report(String kind, String text) async {
  _lines.add('$kind $text');
  _shown.value++;
  try {
    await _post('/report', jsonEncode({'kind': kind, 'text': text}));
  } catch (_) {
    // Помощник недоступен — результат всё равно виден на странице.
  }
}

/// Ждёт, пока условие станет верным; иначе — ошибка с описанием того, чего не дождались.
Future<void> _until(String what, bool Function() ok, {Duration limit = const Duration(seconds: 15)}) async {
  final deadline = DateTime.now().add(limit);
  while (!ok()) {
    if (DateTime.now().isAfter(deadline)) throw StateError('не дождались: $what');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Где упало: для ошибок самого сценария («не дождались…») место не нужно, для остальных — начало стека.
String _where(Object error, StackTrace stack) {
  if (error is StateError) return '';
  final lines = const LineSplitter().convert('$stack').where((l) => l.trim().isNotEmpty).take(8).join(' | ');
  return ' @ $lines';
}

/// То же, что [_until], но условие проверяется по ответу помощника на [command].
Future<void> _untilAsk(
  String what,
  String command,
  bool Function(String reply) ok, {
  Duration limit = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(limit);
  var last = '';
  while (true) {
    last = await _ask(command);
    if (ok(last)) return;
    if (DateTime.now().isAfter(deadline)) throw StateError('не дождались: $what (ответ АТС: «${last.trim()}»)');
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

Future<void> _pause([int ms = 700]) => Future<void>.delayed(Duration(milliseconds: ms));

String _state(CallEngine e) {
  String one(CallInfo? c) => c == null ? '—' : '#${c.id} ${c.phase.name}${c.held ? ' (удержан)' : ''} ${c.number}';
  return 'текущий: ${one(e.call.value)}; второй: ${one(e.other.value)}';
}

Future<void> _run() async {
  final engine = SipEngine();
  final failures = <CallFailure>[];
  engine.failures.listen((f) => failures.add(f.kind));
  var passed = 0;
  var failed = 0;

  /// Один сценарий: любой сбой внутри — «не прошёл», после чего приводим всё в исходное состояние.
  Future<void> scenario(String name, Future<void> Function() body) async {
    failures.clear();
    try {
      await body();
      passed++;
      await _report('PASS', name);
    } catch (e, stack) {
      failed++;
      await _report('FAIL', '$name — $e [${_state(engine)}; сбои: $failures]${_where(e, stack)}');
    }
    // Исходное состояние: ни одного звонка у нас и ни одного нашего канала на АТС.
    for (var i = 0; i < 3 && (engine.call.value != null || engine.other.value != null); i++) {
      try {
        engine.hangUp();
      } catch (e, stack) {
        await _report('FAIL', '$name: «Завершить» при уборке упало — $e${_where(e, stack)}');
      }
      await _pause(900);
    }
    await _ask('hangup-mine');
    await _pause(1200);
  }

  bool active(CallInfo? c) => c != null && c.phase == CallPhase.active && !c.held;
  bool held(CallInfo? c) => c != null && c.phase == CallPhase.active && c.held;

  /// Исходящий на эхо-номер до состояния «разговор».
  Future<int> talkToEcho() async {
    engine.dial(_echo);
    await _until('исходящий на $_echo стал разговором', () => active(engine.call.value));
    return engine.call.value!.id;
  }

  await scenario('регистрация на АТС', () async {
    const account = Account(server: _ws, number: _number, sipDomain: _domain == '' ? null : _domain);
    final result = await engine.connect(account, _password, keepTrying: true).timeout(const Duration(seconds: 20));
    if (result != LinkStatus.online) throw StateError('итог подключения: ${result.state.name} ${result.error?.name}');
  });
  if (failed > 0) {
    await _report('DONE', 'пройдено $passed, не пройдено $failed (без регистрации остальное не проверить)');
    return;
  }

  await scenario('исходящий звонок: разговор, донабор, завершение', () async {
    await talkToEcho();
    engine.sendDtmf('5');
    await _pause();
    if (!active(engine.call.value)) throw StateError('после донабора звонок пропал');
    engine.hangUp();
    await _until('звонок завершён', () => engine.call.value == null);
    if (failures.isNotEmpty) throw StateError('сбои: $failures');
  });

  await scenario('удержание и снятие с удержания', () async {
    await talkToEcho();
    engine.setHeld(true);
    await _until('звонок на удержании', () => held(engine.call.value));
    await _pause(1500);
    engine.setHeld(false);
    await _until('звонок снят с удержания', () => active(engine.call.value));
    await _pause(1000);
    if (!active(engine.call.value)) throw StateError('после снятия с удержания звонок пропал');
  });

  await scenario('входящий звонок: ответ и завершение', () async {
    await _ask('ring');
    await _until('входящий показан', () => engine.call.value?.phase == CallPhase.incoming);
    engine.accept();
    await _until('входящий стал разговором', () => active(engine.call.value));
    await _pause(1000);
    engine.hangUp();
    await _until('звонок завершён', () => engine.call.value == null);
  });

  await scenario('входящий звонок: отклонение', () async {
    await _ask('ring');
    await _until('входящий показан', () => engine.call.value?.phase == CallPhase.incoming);
    engine.hangUp();
    await _until('входящий убран', () => engine.call.value == null);
    await _pause(1500);
    final channels = await _ask('channels');
    if (channels.trim().isNotEmpty) throw StateError('на АТС остались наши каналы: $channels');
  });

  await scenario('входящий звонок: звонящий не дождался', () async {
    await _ask('ring');
    await _until('входящий показан', () => engine.call.value?.phase == CallPhase.incoming);
    await _ask('hangup-mine');
    await _until('входящий пропал сам', () => engine.call.value == null);
  });

  await scenario('второй звонок: ответить, переключиться туда и обратно, завершить по одному', () async {
    final first = await talkToEcho();
    await _ask('ring');
    await _until('второй звонок показан', () => engine.other.value?.phase == CallPhase.incoming);
    final second = engine.other.value!.id;
    engine.acceptOther();
    await _until(
      'второй стал текущим, первый на удержании',
      () => engine.call.value?.id == second && active(engine.call.value) && held(engine.other.value),
    );
    await _pause(1200);
    engine.swap();
    await _until(
      'после переключения текущий — первый',
      () => engine.call.value?.id == first && active(engine.call.value) && held(engine.other.value),
    );
    await _pause(1200);
    engine.swap();
    await _until(
      'после второго переключения текущий — второй',
      () => engine.call.value?.id == second && active(engine.call.value) && held(engine.other.value),
    );
    await _pause(1200);
    engine.hangUp();
    await _until(
      'второй завершён, первый вернулся и снят с удержания',
      () => engine.other.value == null && engine.call.value?.id == first && active(engine.call.value),
    );
    await _pause(1000);
    engine.hangUp();
    await _until('оба звонка завершены', () => engine.call.value == null && engine.other.value == null);
    if (failures.isNotEmpty) throw StateError('сбои: $failures');
  });

  await scenario('второй звонок: отклонить, первый разговор не затронут', () async {
    final first = await talkToEcho();
    await _ask('ring');
    await _until('второй звонок показан', () => engine.other.value?.phase == CallPhase.incoming);
    engine.rejectOther();
    await _until('второй убран', () => engine.other.value == null);
    await _pause(1200);
    if (engine.call.value?.id != first || !active(engine.call.value)) throw StateError('первый разговор пострадал');
  });

  await scenario('входящий звонок: отказ «занято» (как при «Не беспокоить»)', () async {
    await _ask('ring');
    await _until('входящий показан', () => engine.call.value?.phase == CallPhase.incoming);
    engine.reject();
    await _until('входящий убран', () => engine.call.value == null);
    await _pause(1500);
    final channels = await _ask('channels');
    if (channels.trim().isNotEmpty) throw StateError('на АТС остались наши каналы: $channels');
  });

  await scenario('обычный перевод: собеседник уходит на другой номер, наш звонок завершается', () async {
    await _ask('ring');
    await _until('входящий показан', () => engine.call.value?.phase == CallPhase.incoming);
    engine.accept();
    await _until('разговор с A', () => active(engine.call.value));
    await _pause(1000);
    engine.transfer(_echo);
    await _until('наш звонок завершён после перевода', () => engine.call.value == null);
    if (failures.isNotEmpty) throw StateError('сбои: $failures');
    await _pause(1500);
    final ours = await _ask('channels-ours');
    if (ours.trim().isNotEmpty) throw StateError('наш номер всё ещё занят на АТС: $ours');
    final other = await _ask('channels');
    if (other.trim().isEmpty) throw StateError('собеседник A отключён — перевод его никуда не привёл');
  });

  await scenario('перевод с консультацией: «Сначала поговорить» → «Соединить»', () async {
    // Собеседник A звонит нам (его сторона на АТС — отдельный канал), мы отвечаем.
    await _ask('ring-bridged');
    await _until('входящий показан', () => engine.call.value?.phase == CallPhase.incoming);
    engine.accept();
    await _until('разговор с A', () => active(engine.call.value));
    final a = engine.call.value!.id;
    await _pause(1000);
    // Консультация: A на удержании, звоним B (эхо-номер).
    engine.consult(_echo);
    await _until(
      'разговор с B, A на удержании',
      () => engine.call.value?.id != a && active(engine.call.value) && held(engine.other.value),
      limit: const Duration(seconds: 20),
    );
    await _pause(1500);
    engine.connectCalls();
    await _until(
      'оба звонка ушли с нашего телефона',
      () => engine.call.value == null && engine.other.value == null,
      limit: const Duration(seconds: 20),
    );
    if (failures.isNotEmpty) throw StateError('АТС не соединила: $failures');
    await _pause(1500);
    // На АТС собеседник A должен остаться в разговоре (теперь с B), а наших каналов быть не должно.
    final ours = await _ask('channels-ours');
    if (ours.trim().isNotEmpty) throw StateError('наш номер всё ещё занят на АТС: $ours');
    final other = await _ask('channels');
    if (other.trim().isEmpty) throw StateError('собеседник A отключён — АТС его ни с кем не соединила');
  });

  await scenario('«Соединить» двух собеседников, когда текущий звонок — входящий', () async {
    // B — наш исходящий (эхо-номер); затем звонит A, отвечаем — B уходит на удержание.
    final b = await talkToEcho();
    await _ask('ring');
    await _until('второй звонок показан', () => engine.other.value?.phase == CallPhase.incoming);
    engine.acceptOther();
    await _until(
      'разговор с A, B на удержании',
      () => engine.call.value?.id != b && active(engine.call.value) && held(engine.other.value),
    );
    await _pause(1500);
    engine.connectCalls();
    await _until(
      'оба звонка ушли с нашего телефона',
      () => engine.call.value == null && engine.other.value == null,
      limit: const Duration(seconds: 20),
    );
    if (failures.isNotEmpty) throw StateError('АТС не соединила: $failures');
    await _pause(1500);
    final ours = await _ask('channels-ours');
    if (ours.trim().isNotEmpty) throw StateError('наш номер всё ещё занят на АТС: $ours');
    final other = await _ask('channels');
    if (other.trim().isEmpty) throw StateError('собеседник A отключён — АТС его ни с кем не соединила');
  });

  await scenario('статус своего номера: свободен → разговаривает → свободен', () async {
    engine.watchPresence({_number});
    await _until('статус «свободен»', () => engine.presence.value[_number] == Presence.free);
    await talkToEcho();
    await _until('статус «разговаривает»', () => engine.presence.value[_number] == Presence.busy);
    engine.hangUp();
    await _until('снова «свободен»', () => engine.presence.value[_number] == Presence.free);
  });

  await scenario('режим «будить по звонку»: адрес для push уходит на АТС, «уснуть» снимает регистрацию', () async {
    const account = Account(server: _ws, number: _number, sipDomain: _domain == '' ? null : _domain);
    // Адрес телефона для push — как у настоящего по длине и набору знаков, но выдуманный.
    final token = '${'c9XkT0Qw_E2:APA91b'}${'Hq7-zLmN4pR_s' * 10}';
    final info = PushInfo(provider: 'fcm', project: 'sado-stand-check', token: token);

    await engine.sleep();
    if (engine.link.value.isOnline) throw StateError('после «уснуть» движок считает себя на связи');
    await _untilAsk('на АТС нет нашей регистрации', 'contact', (reply) => reply.trim().isEmpty);

    final result = await engine
        .connect(account, _password, keepTrying: true, push: info)
        .timeout(const Duration(seconds: 20));
    if (result != LinkStatus.online) throw StateError('с параметрами push АТС не зарегистрировала: $result');
    await _untilAsk(
      'в адресе регистрации на АТС есть параметры push',
      'contact',
      (reply) =>
          reply.contains('pn-provider=fcm') && reply.contains('pn-param=sado-stand-check') && reply.contains(token),
    );
    // С таким адресом звонки должны приходить как обычно.
    await _ask('ring');
    await _until('входящий показан', () => engine.call.value?.phase == CallPhase.incoming);
    engine.accept();
    await _until('входящий стал разговором', () => active(engine.call.value));
    engine.hangUp();
    await _until('звонок завершён', () => engine.call.value == null);

    await engine.sleep();
    await _untilAsk('после «уснуть» регистрации на АТС нет', 'contact', (reply) => reply.trim().isEmpty);
    // Возвращаемся на связь без параметров push — как в обычном режиме.
    final back = await engine.connect(account, _password, keepTrying: true).timeout(const Duration(seconds: 20));
    if (back != LinkStatus.online) throw StateError('не удалось вернуться на связь: $back');
    await _untilAsk('обычная регистрация без параметров push', 'contact', (reply) {
      return reply.trim().isNotEmpty && !reply.contains('pn-prid');
    });
  });

  await _report('DONE', 'пройдено $passed, не пройдено $failed');
  engine.dispose();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<int>(
        valueListenable: _shown,
        builder: (context, _, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            ['Проверка SADO на АТС', ..._lines].join('\n'),
            style: const TextStyle(color: Color(0xFF202020), fontSize: 14, height: 1.5),
          ),
        ),
      ),
    ),
  );
  unawaited(
    _run().catchError((Object e) async {
      await _report('FAIL', 'проверка прервалась: $e');
      await _report('DONE', 'прервано');
    }),
  );
}

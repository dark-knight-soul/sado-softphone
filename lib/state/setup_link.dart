import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sip/call_engine.dart';

/// Ссылка настройки: администратор выдаёт её человеку (обычно QR-кодом), и SADO открывается
/// с заполненной формой входа. Формат — для документации администраторам:
///
/// ```
/// sado://login?server=<сервер>&number=<номер>&password=<пароль>
/// ```
///
/// * все значения кодируются как в адресах (`%XX`); знак `+` остаётся плюсом, пробел пишется `%20`;
/// * `server` — обязателен: имя сервера (можно с портом и путём, `pbx.example.com:8089/ws`)
///   или полный адрес `wss://…` / `ws://…`; другие схемы (`http:`, `javascript:` …) не принимаются;
/// * `number` — обязателен: внутренний номер (лишние знаки отбрасываются, как при наборе);
/// * `password` — необязателен: без него человек введёт пароль сам;
/// * прочие параметры не учитываются; повтор `server`, `number` или `password` делает ссылку недействительной.
///
/// Сама ссылка никогда не выполняет вход: она только заполняет форму, «Войти» человек нажимает сам —
/// иначе чужая ссылка могла бы незаметно подключить телефон к чужой АТС.
@immutable
class SetupLink {
  const SetupLink({required this.server, required this.number, this.password});

  final String server;
  final String number;
  final String? password;

  // Пароль не должен попасть в журнал даже случайно, через печать объекта.
  @override
  String toString() => 'SetupLink($server, $number, password: ${password == null ? 'нет' : 'есть'})';
}

/// Длиннее ссылку не разбираем: это уже не настройка, а мусор (на Android та же граница).
const maxSetupLinkLength = 1000;

const _maxServer = 200;
const _maxNumber = 32;
const _maxPassword = 128;

/// Пробелы и управляющие знаки в адресе сервера.
final _badServerChars = RegExp(r'[\s\x00-\x1F\x7F]');

/// Управляющие знаки в пароле (пробел в пароле допустим).
final _controlChars = RegExp(r'[\x00-\x1F\x7F]');

/// Начало «схема:» — но не «имя:порт» (после двоеточия сразу цифра).
final _schemePrefix = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:(?![0-9])');

/// Разбирает и проверяет ссылку настройки. Всё, что не подходит, — null: такую ссылку просто не замечаем.
/// Функция чистая, без побочных действий, чтобы её можно было проверить тестами.
SetupLink? parseSetupLink(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text.length > maxSetupLinkLength) return null;
  final uri = Uri.tryParse(text);
  // Uri сам приводит схему и имя к нижнему регистру.
  if (uri == null || uri.scheme != 'sado' || uri.host != 'login') return null;

  // Параметры разбираем сами: стандартный разбор превращает «+» в пробел и испортил бы такой пароль.
  final params = <String, String>{};
  if (uri.hasQuery && uri.query.isNotEmpty) {
    for (final part in uri.query.split('&')) {
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      final String key, value;
      try {
        key = Uri.decodeComponent(eq < 0 ? part : part.substring(0, eq));
        value = eq < 0 ? '' : Uri.decodeComponent(part.substring(eq + 1));
      } on ArgumentError {
        return null; // испорченное %-кодирование
      } on FormatException {
        return null;
      }
      if (key != 'server' && key != 'number' && key != 'password') continue;
      // Два разных значения одного поля — неясно, какое имел в виду администратор; не гадаем.
      if (params.containsKey(key)) return null;
      params[key] = value;
    }
  }

  final server = _cleanServer(params['server']);
  if (server == null) return null;

  final rawNumber = params['number'];
  if (rawNumber == null) return null;
  final number = dialTarget(rawNumber);
  if (number.isEmpty || number.length > _maxNumber) return null;

  var password = params['password'];
  if (password != null) {
    if (password.length > _maxPassword || _controlChars.hasMatch(password)) return null;
    if (password.isEmpty) password = null; // пустой пароль — то же, что его нет
  }
  return SetupLink(server: server, number: number, password: password);
}

/// Адрес сервера: имя (с портом и путём) или полный ws:// / wss://. Иначе — null.
String? _cleanServer(String? raw) {
  if (raw == null) return null;
  var server = raw.trim();
  if (server.isEmpty || server.length > _maxServer || _badServerChars.hasMatch(server)) return null;
  final lower = server.toLowerCase();
  for (final scheme in const ['wss://', 'ws://']) {
    if (lower.startsWith(scheme)) {
      // Схему пишем строчными: дальше адрес сравнивается с «wss://» буквально (см. account.dart).
      final rest = server.substring(scheme.length);
      if (rest.isEmpty || rest.startsWith('/')) return null;
      return '$scheme$rest';
    }
  }
  // Любая другая схема (http:, javascript:, file: …) — не адрес АТС.
  if (server.contains('://') || _schemePrefix.hasMatch(server)) return null;
  if (server.startsWith('/')) return null;
  return server;
}

/// Ссылка настройки, которую ещё не обработал экран. Пока не обработана — не null.
/// Пароль живёт здесь лишь до применения: экран входа переносит его в поле и сразу стирает запрос.
class SetupRequestNotifier extends Notifier<SetupLink?> {
  @override
  SetupLink? build() => null;

  /// Принимает ссылку снаружи; недействительная просто не замечается.
  void request(String raw) {
    final link = parseSetupLink(raw);
    if (link != null) state = link;
  }

  /// Запрос выполнен (или отклонён) — забываем его вместе с паролем.
  void clear() => state = null;
}

final setupRequestProvider = NotifierProvider<SetupRequestNotifier, SetupLink?>(SetupRequestNotifier.new);

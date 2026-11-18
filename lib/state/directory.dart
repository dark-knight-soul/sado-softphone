import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'directory_web.dart' if (dart.library.io) 'directory_io.dart';
import 'password_store.dart';
import 'pbx_features.dart';
import 'session.dart';
import 'settings.dart';

/// Сотрудник из справочника АТС.
@immutable
class DirectoryEntry {
  const DirectoryEntry({required this.number, required this.name, this.department = ''});

  final String number;
  final String name;

  /// Отдел; пустая строка — без отдела.
  final String department;

  Map<String, dynamic> toJson() => {'number': number, 'name': name, 'department': department};
}

/// Справочник сотрудников и возможности АТС — то, что она сообщила приложению.
@immutable
class DirectoryData {
  const DirectoryData({required this.entries, this.features = PbxFeatures.none, this.etag});

  /// В порядке сервера: по отделам, внутри — по имени. Своего номера здесь нет.
  final List<DirectoryEntry> entries;
  final PbxFeatures features;

  /// Метка версии ответа: с ней сервер отвечает «не изменилось», и список не качается заново.
  final String? etag;

  Map<String, dynamic> toJson() => {
    'entries': [for (final e in entries) e.toJson()],
    'features': {
      'conference': features.conferencePrefix,
      'conference_digits': features.conferenceDigits,
      'record': features.recordCode,
    },
    'etag': etag,
  };
}

/// Больше записей и более длинные строки не берём: ответ сервера — чужие данные, и ошибка (или злой умысел)
/// на его стороне не должна раздуть память или сохранённые настройки.
const _maxEntries = 2000;
const _maxText = 80;

/// Служебный код АТС: звёздочка, решётка и цифры, недлинный. Другое — не код, и набирать его мы не станем.
String? _code(Object? raw) => raw is String && RegExp(r'^[0-9*#]{1,8}$').hasMatch(raw) ? raw : null;

String _text(Object? raw) {
  if (raw is! String) return '';
  final t = raw.trim();
  return t.length > _maxText ? t.substring(0, _maxText) : t;
}

/// Возможности АТС из блока `features` её ответа; чего в нём нет или что записано не так — того нет.
PbxFeatures featuresFrom(Object? raw) {
  if (raw is! Map) return PbxFeatures.none;
  final digits = raw['conference_digits'];
  return PbxFeatures(
    conferencePrefix: _code(raw['conference']),
    conferenceDigits: digits is int && digits >= 1 && digits <= 12 ? digits : 6,
    recordCode: _code(raw['record']),
  );
}

/// Разбирает ответ справочника (и сохранённую копию). null — это не справочник.
/// [self] — свой номер: себя в списке не показываем.
DirectoryData? parseDirectory(String body, {required String self, String? etag}) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (json is! Map) return null;
  final raw = json['entries'];
  if (raw is! List) return null;
  final entries = <DirectoryEntry>[];
  final seen = <String>{};
  for (final item in raw) {
    if (entries.length >= _maxEntries) break;
    if (item is! Map) continue;
    final number = _text(item['number']);
    final name = _text(item['name']);
    // Номер без имени бесполезен, как и имя без номера; повторы и самого себя пропускаем.
    if (number.isEmpty || name.isEmpty || number == self || !seen.add(number)) continue;
    entries.add(DirectoryEntry(number: number, name: name, department: _text(item['department'])));
  }
  final savedEtag = json['etag'];
  return DirectoryData(
    entries: entries,
    features: featuresFrom(json['features']),
    etag: etag ?? (savedEtag is String ? savedEtag : null),
  );
}

/// Адрес справочника для учётной записи: тот же сервер, что и для звонков, всегда по HTTPS.
/// null — сервера нет (учебная запись) или его имя не разобрать.
Uri? directoryUrl(Account account) {
  if (account.isDemo) return null;
  final host = Uri.tryParse(account.wsUrl)?.host ?? '';
  if (host.isEmpty) return null;
  return Uri(scheme: 'https', host: host, path: '/api/v1/directory');
}

/// Представился ли сервер справочником SADO: в заголовке `WWW-Authenticate` — способ входа Basic
/// и область (realm) «sado». Остальные параметры заголовка (например, кодировка) значения не имеют.
bool isSadoChallenge(String? header) {
  if (header == null) return false;
  final value = header.trim();
  if (!RegExp(r'^basic(\s|$)', caseSensitive: false).hasMatch(value)) return false;
  final realm = RegExp(r'realm\s*=\s*("([^"]*)"|[^,\s]+)', caseSensitive: false).firstMatch(value);
  if (realm == null) return false;
  return (realm.group(2) ?? realm.group(1))!.toLowerCase() == 'sado';
}

/// Что ответил сервер на запрос справочника.
sealed class DirectoryReply {
  const DirectoryReply();
}

class DirectoryLoaded extends DirectoryReply {
  const DirectoryLoaded(this.body, this.etag);

  final String body;
  final String? etag;
}

/// С прошлого раза ничего не изменилось.
class DirectoryNotModified extends DirectoryReply {
  const DirectoryNotModified();
}

/// Сервер не принял номер и пароль. Повторять нельзя: за несколько отказов он блокирует адрес.
class DirectoryDenied extends DirectoryReply {
  const DirectoryDenied();
}

/// Сервер временно заблокировал адрес за частые отказы во входе.
class DirectoryBlocked extends DirectoryReply {
  const DirectoryBlocked();
}

/// Справочника на этом сервере нет (или там совсем другой сервер).
class DirectoryAbsent extends DirectoryReply {
  const DirectoryAbsent();
}

/// До сервера не достучались: нет сети, не тот сертификат, таймаут.
class DirectoryUnreachable extends DirectoryReply {
  const DirectoryUnreachable();
}

/// Запросы к справочнику. В тестах подменяется.
abstract class DirectoryClient {
  /// Проба БЕЗ номера и пароля: отвечает ли сервер как справочник SADO (отказом с пометкой «sado»).
  /// true — да, false — нет, null — узнать не удалось (сеть). Пароль отправляется только после «да»:
  /// на том же адресе может стоять посторонний сайт, и ему пароль от телефонии знать незачем.
  Future<bool?> probe(Uri url);

  Future<DirectoryReply> fetch(Uri url, {required String number, required String password, String? etag});
}

final directoryClientProvider = Provider<DirectoryClient>((ref) => createDirectoryClient());

/// Справочник сотрудников текущей учётной записи; null — его нет (АТС его не отдаёт или ещё не спрашивали).
///
/// Спрашивается у АТС, когда приложение вышло на связь (значит, номер и пароль верны), не чаще раза
/// в десять минут. Последний ответ хранится на телефоне, чтобы список был виден и без сети; при выходе
/// из учётной записи он стирается.
class DirectoryController extends Notifier<DirectoryData?> {
  static const _kCache = 'directory.cache';
  static const _kKnown = 'directory.known';
  static const _kAbsentAt = 'directory.absentAt';

  /// Ключи сохранённых данных справочника — чтобы стереть их при выходе из учётной записи.
  static const storedKeys = [_kCache, _kKnown, _kAbsentAt];

  static const refreshEvery = Duration(minutes: 10);

  /// Если сервер оказался не справочником, снова проверяем не раньше чем через сутки.
  static const absentFor = Duration(hours: 24);

  /// На сколько сервер блокирует адрес — столько не спрашиваем и мы.
  static const blockedFor = Duration(minutes: 15);

  DateTime? _lastAttempt;
  DateTime? _blockedUntil;
  bool _denied = false;
  bool _busy = false;

  @override
  DirectoryData? build() {
    final account = ref.watch(sessionProvider);
    _lastAttempt = null;
    _blockedUntil = null;
    _denied = false;
    if (account == null || directoryUrl(account) == null) return null;
    // Вышли на связь — номер и пароль верны, можно спрашивать справочник.
    ref.listen(linkProvider, (previous, next) {
      if (next.isOnline && !(previous?.isOnline ?? false)) unawaited(refresh());
    });
    if (ref.read(linkProvider).isOnline) Future.microtask(refresh);
    return _cached(account);
  }

  String _owner(Account account) => '${directoryUrl(account)!.host}|${account.number}';

  DirectoryData? _cached(Account account) {
    final raw = ref.read(prefsProvider).getString(_kCache);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['for'] != _owner(account)) return null;
      return parseDirectory(jsonEncode(json['data']), self: account.number);
    } catch (_) {
      return null;
    }
  }

  /// Спросить справочник у АТС. [force] — не ждать десяти минут с прошлой попытки (человек открыл контакты).
  Future<void> refresh({bool force = false}) async {
    final account = ref.read(sessionProvider);
    if (account == null || _busy || _denied) return;
    final url = directoryUrl(account);
    if (url == null) return;
    final now = clock.now();
    final blocked = _blockedUntil;
    if (blocked != null && now.isBefore(blocked)) return;
    final last = _lastAttempt;
    final gap = force ? const Duration(minutes: 1) : refreshEvery;
    if (last != null && now.difference(last) < gap) return;
    _lastAttempt = now;
    _busy = true;
    try {
      await _load(account, url);
    } finally {
      _busy = false;
    }
  }

  Future<void> _load(Account account, Uri url) async {
    final prefs = ref.read(prefsProvider);
    final client = ref.read(directoryClientProvider);
    if (prefs.getString(_kKnown) != url.host) {
      final absentAt = prefs.getInt(_kAbsentAt);
      if (absentAt != null && clock.now().millisecondsSinceEpoch - absentAt < absentFor.inMilliseconds) return;
      final isDirectory = await client.probe(url);
      if (!ref.mounted || ref.read(sessionProvider) != account) return;
      if (isDirectory == null) return; // сеть — попробуем в следующий раз
      if (!isDirectory) {
        await prefs.setInt(_kAbsentAt, clock.now().millisecondsSinceEpoch);
        return;
      }
      await prefs.setString(_kKnown, url.host);
      await prefs.remove(_kAbsentAt);
    }
    final password = await ref.read(passwordStoreProvider).read();
    if (password == null || !ref.mounted || ref.read(sessionProvider) != account) return;
    final reply = await client.fetch(url, number: account.number, password: password, etag: state?.etag);
    // Пока ждали ответа, человек мог выйти или войти под другим номером — чужой список не показываем.
    if (!ref.mounted || ref.read(sessionProvider) != account) return;
    switch (reply) {
      case DirectoryLoaded(:final body, :final etag):
        final data = parseDirectory(body, self: account.number, etag: etag);
        if (data == null) return;
        state = data;
        await prefs.setString(_kCache, jsonEncode({'for': _owner(account), 'data': data.toJson()}));
      case DirectoryNotModified():
        break;
      case DirectoryDenied():
        // Пароль от телефонии подошёл, а здесь — нет: спрашивать снова бессмысленно и опасно (блокировка).
        _denied = true;
      case DirectoryBlocked():
        _blockedUntil = clock.now().add(blockedFor);
      case DirectoryAbsent():
        // Сервер больше не отвечает как справочник — в следующий раз начнём с пробы.
        await prefs.remove(_kKnown);
      case DirectoryUnreachable():
        break;
    }
  }
}

final directoryProvider = NotifierProvider<DirectoryController, DirectoryData?>(DirectoryController.new);

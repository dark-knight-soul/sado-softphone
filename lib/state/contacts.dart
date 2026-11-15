import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import 'session.dart';
import 'settings.dart';

/// Записная книжка. Хранится на телефоне; у демонстрационной учётной записи — готовый образец.
/// Когда сервер Sado научится отдавать список сотрудников, он добавится сюда же.
class ContactsController extends Notifier<List<Contact>> {
  static const _key = 'contacts';

  bool _demo = false;

  @override
  List<Contact> build() {
    final account = ref.watch(sessionProvider);
    _demo = account?.isDemo ?? false;
    if (account == null) return const [];
    if (_demo) return demoContacts;
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return _sorted([for (final item in jsonDecode(raw) as List) Contact.fromJson(item as Map<String, dynamic>)]);
    } catch (_) {
      return const [];
    }
  }

  List<Contact> _sorted(List<Contact> list) =>
      [...list]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _set(List<Contact> next) {
    state = _sorted(next);
    if (!_demo) ref.read(prefsProvider).setString(_key, jsonEncode([for (final c in state) c.toJson()]));
  }

  void add(Contact contact) => _set([...state, contact]);

  void replace(Contact old, Contact updated) => _set([for (final c in state) identical(c, old) ? updated : c]);

  void remove(Contact contact) => _set([
    for (final c in state)
      if (!identical(c, contact)) c,
  ]);

  /// Имя по номеру, если такой контакт есть.
  String? nameOf(String number) {
    if (number.isEmpty) return null;
    for (final c in state) {
      if (c.number == number) return c.name;
    }
    return null;
  }
}

final contactsProvider = NotifierProvider<ContactsController, List<Contact>>(ContactsController.new);

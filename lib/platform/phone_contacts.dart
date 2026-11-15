import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import '../state/contacts.dart';
import '../state/session.dart';
import '../state/settings.dart';

/// Адресная книга телефона. Только чтение: ничего не копируется и никуда не отправляется,
/// имена нужны лишь для показа в списке, истории и на экране звонка.
abstract class PhoneContacts {
  /// Дано ли приложению разрешение читать контакты.
  Future<bool> granted();

  /// Спрашивает разрешение; ответ — дал человек его или нет.
  Future<bool> request();

  /// Все номера из адресной книги: имя и номер (у человека с тремя номерами — три записи).
  Future<List<Contact>> list();
}

/// Там, где адресной книги нет (браузер), ничего не делает.
class NoopPhoneContacts extends PhoneContacts {
  @override
  Future<bool> granted() async => false;

  @override
  Future<bool> request() async => false;

  @override
  Future<List<Contact>> list() async => const [];
}

class AndroidPhoneContacts extends PhoneContacts {
  static const _channel = MethodChannel('uz.sado.app/contacts');

  /// Сбой телефона не должен ронять приложение: просто считаем, что контактов нет.
  Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null; // запущено не на Android
    }
  }

  @override
  Future<bool> granted() async => await _invoke<bool>('granted') ?? false;

  @override
  Future<bool> request() async => await _invoke<bool>('request') ?? false;

  @override
  Future<List<Contact>> list() async {
    final raw = await _invoke<List<Object?>>('list') ?? const [];
    return [
      for (final item in raw)
        if (item is Map && item['number'] is String && (item['number'] as String).trim().isNotEmpty)
          Contact(name: (item['name'] as String?) ?? '', number: (item['number'] as String).trim()),
    ];
  }
}

final phoneContactsProvider = Provider<PhoneContacts>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? AndroidPhoneContacts() : NoopPhoneContacts(),
);

/// Номер для сравнения: без пробелов, скобок и дефисов; плюс в начале сохраняется.
String normalizeNumber(String number) {
  final t = number.trim();
  final digits = t.replaceAll(RegExp(r'\D'), '');
  return t.startsWith('+') ? '+$digits' : digits;
}

/// Контакты телефона доступны только на Android и не в демонстрационной учётной записи.
bool phoneContactsAvailable(Account? account) => !kIsWeb && account != null && !account.isDemo;

/// Контакты телефона, загруженные в память. Нигде не сохраняются: каждый раз читаются заново.
class PhoneContactList extends Notifier<List<Contact>> with WidgetsBindingObserver {
  bool _alive = true;

  @override
  List<Contact> build() {
    _alive = true;
    final on = ref.watch(settingsProvider.select((s) => s.phoneContacts));
    final available = phoneContactsAvailable(ref.watch(sessionProvider));
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _alive = false;
      WidgetsBinding.instance.removeObserver(this);
    });
    if (!on || !available) return const [];
    // Загрузка идёт после сборки: в build нельзя менять состояние.
    Future.microtask(refresh);
    return const [];
  }

  /// Вернулись в приложение: человек мог поменять адресную книгу или разрешение.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) refresh();
  }

  /// Перечитывает адресную книгу — одним вызовом к телефону.
  Future<void> refresh() async {
    if (!_alive) return;
    final on = ref.read(settingsProvider).phoneContacts;
    if (!on || !phoneContactsAvailable(ref.read(sessionProvider))) return;
    final source = ref.read(phoneContactsProvider);
    final List<Contact> loaded;
    if (!await source.granted()) {
      loaded = const [];
    } else {
      final raw = await source.list();
      loaded = [...raw]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    // Пока ждали телефон, человек мог выключить показ или закрыть приложение.
    if (!_alive || !ref.read(settingsProvider).phoneContacts) return;
    state = loaded;
  }

  /// Просит разрешение и, если дали, включает показ. Отказ ничего не меняет.
  Future<void> enable() async {
    if (!await ref.read(phoneContactsProvider).request()) return;
    if (!_alive) return;
    ref.read(settingsProvider.notifier).setPhoneContacts(true);
  }
}

final phoneContactListProvider = NotifierProvider<PhoneContactList, List<Contact>>(PhoneContactList.new);

/// Контакты телефона для показа: без тех, чей номер уже есть среди своих контактов.
final visiblePhoneContactsProvider = Provider<List<Contact>>((ref) {
  final own = {for (final c in ref.watch(contactsProvider)) normalizeNumber(c.number)};
  return [
    for (final c in ref.watch(phoneContactListProvider))
      if (!own.contains(normalizeNumber(c.number))) c,
  ];
});

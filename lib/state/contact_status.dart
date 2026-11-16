import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import 'contacts.dart';
import 'session.dart';

/// Статусы своих контактов по данным АТС: номер → свободен / говорит / не в сети.
///
/// Просит движок следить за номерами из записной книжки и пересказывает, что сообщила АТС.
/// Если АТС статусы не отдаёт (нет подписки или номера ей неизвестны), словарь просто пуст —
/// в списке контактов тогда виден один номер, как раньше.
///
/// Подписка начинается, когда этот список впервые понадобился экрану (то есть когда человек
/// открыл контакты), и живёт до выхода из учётной записи.
class ContactStatusController extends Notifier<Map<String, Presence>> {
  @override
  Map<String, Presence> build() {
    final engine = ref.watch(engineProvider);
    if (engine == null) return const {};
    final contacts = ref.watch(contactsProvider);
    engine.watchPresence({
      for (final c in contacts)
        if (!c.isGroup) c.number,
    });
    void sync() => state = engine.presence.value;
    engine.presence.addListener(sync);
    ref.onDispose(() => engine.presence.removeListener(sync));
    return engine.presence.value;
  }
}

final contactStatusProvider = NotifierProvider<ContactStatusController, Map<String, Presence>>(
  ContactStatusController.new,
);

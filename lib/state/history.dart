import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import 'session.dart';
import 'settings.dart';

/// История звонков. Хранится на телефоне (последние [_limit] записей).
/// У демонстрационной учётной записи — готовый образец, на телефон он не записывается.
class HistoryController extends Notifier<List<HistoryEntry>> {
  static const _key = 'history';
  static const _limit = 200;

  bool _demo = false;

  @override
  List<HistoryEntry> build() {
    final account = ref.watch(sessionProvider);
    _demo = account?.isDemo ?? false;
    if (account == null) return const [];
    if (_demo) return demoHistory();
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [for (final item in jsonDecode(raw) as List) HistoryEntry.fromJson(item as Map<String, dynamic>)];
    } catch (_) {
      // Испорченную запись не чиним — начинаем историю заново.
      return const [];
    }
  }

  void add(HistoryEntry entry) {
    final next = [entry, ...state];
    if (next.length > _limit) next.removeRange(_limit, next.length);
    state = next;
    if (!_demo) {
      ref.read(prefsProvider).setString(_key, jsonEncode([for (final e in next) e.toJson()]));
    }
  }

  /// Стирает историю с телефона (при выходе из учётной записи).
  Future<void> clear() => ref.read(prefsProvider).remove(_key);
}

final historyProvider = NotifierProvider<HistoryController, List<HistoryEntry>>(HistoryController.new);

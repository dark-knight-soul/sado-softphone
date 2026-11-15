import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sip/call_engine.dart';
import 'call.dart';
import 'session.dart';

/// Номер, который просит подставить ссылка tel: или sip: из другого приложения. Пока не обработан — не null.
/// Звонок отсюда никогда не начинается: номер лишь попадает в поле набора, звонит человек сам.
class DialRequestNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Принимает номер снаружи. Чужому тексту не верим: оставляем только допустимые в номере символы.
  /// Без входа в учётную запись или во время звонка запрос отбрасывается.
  void request(String raw) {
    final number = dialTarget(raw);
    if (number.isEmpty) return;
    if (ref.read(sessionProvider) == null) return;
    if (ref.read(callProvider) != null) return;
    state = number;
  }

  /// Запрос выполнен (или не нужен) — забываем его.
  void clear() => state = null;
}

final dialRequestProvider = NotifierProvider<DialRequestNotifier, String?>(DialRequestNotifier.new);

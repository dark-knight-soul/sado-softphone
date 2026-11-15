import 'package:flutter/foundation.dart';

/// Учётная запись на АТС: что человек ввёл в поле «Сервер» и его номер.
/// Пароль здесь не хранится — он лежит отдельно, в защищённом хранилище телефона.
@immutable
class Account {
  const Account({required this.server, required this.number, this.sipDomain});

  /// Слово в поле «Сервер», которое включает демонстрацию без настоящей АТС.
  static const demoServer = 'demo';

  final String server;
  final String number;

  /// Домен SIP, если он отличается от адреса подключения. В интерфейсе пока не задаётся; нужен для
  /// проверки на АТС, к которой подключаются по одному адресу (например, 127.0.0.1), а домен у неё другой.
  final String? sipDomain;

  bool get isDemo => server.trim().toLowerCase() == demoServer;

  /// Адрес WebSocket (канала, по которому приложение разговаривает с АТС).
  ///
  /// Можно ввести полный адрес (`ws://192.0.2.10:8080/ws`) — он берётся как есть.
  /// Если введено только имя сервера, подставляется защищённый вариант: `wss://имя/ws`.
  String get wsUrl {
    final s = server.trim();
    if (s.startsWith('ws://') || s.startsWith('wss://')) return s;
    return 'wss://$s/ws';
  }

  /// Имя сервера без схемы, порта и пути — оно стоит после «@» в SIP-адресе (`1003@домен`).
  String get domain {
    final explicit = sipDomain;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    var s = server.trim();
    final scheme = s.indexOf('://');
    if (scheme >= 0) s = s.substring(scheme + 3);
    final slash = s.indexOf('/');
    if (slash >= 0) s = s.substring(0, slash);
    // IPv6 в квадратных скобках оставляем как есть, у остального отрезаем порт.
    if (!s.startsWith('[')) {
      final colon = s.lastIndexOf(':');
      if (colon >= 0) s = s.substring(0, colon);
    }
    return s;
  }

  /// Шифруется ли связь с сервером (wss). Сам звук в WebRTC шифруется всегда.
  bool get secureTransport => wsUrl.startsWith('wss://');

  @override
  bool operator ==(Object other) => other is Account && other.server == server && other.number == number;

  @override
  int get hashCode => Object.hash(server, number);
}

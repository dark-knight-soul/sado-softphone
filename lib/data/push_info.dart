/// Как АТС может разбудить этот телефон push-уведомлением.
class PushInfo {
  const PushInfo({required this.provider, required this.project, required this.token});

  /// Разбирает ответ телефона; неполный или непонятный ответ — push нет.
  static PushInfo? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final provider = raw['provider'];
    final project = raw['project'];
    final token = raw['token'];
    if (provider is! String || project is! String || token is! String) return null;
    if (provider.isEmpty || project.isEmpty || token.isEmpty) return null;
    return PushInfo(provider: provider, project: project, token: token);
  }

  /// Служба доставки: сейчас только «fcm» (Google).
  final String provider;

  /// Проект в службе доставки, от имени которого АТС отправляет push.
  final String project;

  /// Адрес этого телефона в службе доставки. Не секрет, но и не для чужих глаз: в журналы не пишем.
  final String token;

  @override
  bool operator ==(Object other) =>
      other is PushInfo && other.provider == provider && other.project == project && other.token == token;

  @override
  int get hashCode => Object.hash(provider, project, token);
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sip/call_engine.dart';
import '../sip/demo_engine.dart';
// Настоящий движок подключается только там, где он собирается; в браузере — заглушка.
import '../sip/real_engine_web.dart' if (dart.library.io) '../sip/real_engine_io.dart';
import 'account.dart';
import 'password_store.dart';
import 'settings.dart';

export 'account.dart';

/// Какой движок звонков нужен учётной записи. В тестах подменяется на имитацию.
final engineFactoryProvider = Provider<CallEngine Function(Account)>(
  (ref) =>
      (account) => account.isDemo ? DemoEngine() : createRealEngine(),
);

/// Кто вошёл в приложение (null — никто).
class SessionController extends Notifier<Account?> {
  static const _kServer = 'account.server';
  static const _kNumber = 'account.number';

  /// Движок, уже подключённый на экране входа. Его забирает [engineProvider],
  /// чтобы не подключаться к АТС второй раз.
  CallEngine? _ready;

  @override
  Account? build() {
    ref.onDispose(() => _ready?.dispose());
    final p = ref.watch(prefsProvider);
    final server = p.getString(_kServer);
    final number = p.getString(_kNumber);
    if (server == null || number == null) return null;
    return Account(server: server, number: number);
  }

  /// Вход: сначала проверяем номер и пароль на АТС, и только при успехе запоминаем учётную запись.
  Future<LinkStatus> signIn({required String server, required String number, required String password}) async {
    final account = Account(server: server, number: number);
    final engine = ref.read(engineFactoryProvider)(account);
    final LinkStatus result;
    try {
      result = await engine.connect(account, password);
    } catch (_) {
      engine.dispose();
      return const LinkStatus(LinkState.failed, LinkError.other);
    }
    if (!result.isOnline) {
      engine.dispose();
      return result;
    }
    try {
      if (!account.isDemo) await ref.read(passwordStoreProvider).write(password);
      final p = ref.read(prefsProvider);
      await p.setString(_kServer, server);
      await p.setString(_kNumber, number);
    } catch (_) {
      // Не удалось сохранить (например, сбой защищённого хранилища): не оставляем номер подключённым «втихую».
      engine.dispose();
      return const LinkStatus(LinkState.failed, LinkError.other);
    }
    _ready?.dispose();
    _ready = engine;
    state = account;
    return result;
  }

  Future<void> signOut() async {
    final p = ref.read(prefsProvider);
    await p.remove(_kServer);
    await p.remove(_kNumber);
    // История звонков — личные данные: при выходе стираем (ключ тот же, что в history.dart).
    await p.remove('history');
    await ref.read(passwordStoreProvider).clear();
    state = null;
  }

  /// Отдаёт движок для учётной записи: готовый после входа или новый — при запуске приложения
  /// с сохранённой учётной записью (тогда он подключается сам, в фоне).
  CallEngine takeEngine(Account account) {
    final ready = _ready;
    if (ready != null) {
      _ready = null;
      return ready;
    }
    final engine = ref.read(engineFactoryProvider)(account);
    unawaited(_connectSaved(engine, account));
    return engine;
  }

  Future<void> _connectSaved(CallEngine engine, Account account) async {
    try {
      final password = account.isDemo ? '' : await ref.read(passwordStoreProvider).read();
      if (password == null) {
        // Пароля в хранилище нет (например, данные приложения очищены) — просим войти заново.
        await signOut();
        return;
      }
      await engine.connect(account, password, keepTrying: true);
    } catch (_) {
      // Движок мог быть уже закрыт (человек вышел, пока шло подключение) — это не ошибка.
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, Account?>(SessionController.new);

/// Движок звонков текущей учётной записи. Живёт, пока человек не вышел.
final engineProvider = Provider<CallEngine?>((ref) {
  final account = ref.watch(sessionProvider);
  if (account == null) return null;
  final engine = ref.read(sessionProvider.notifier).takeEngine(account);
  ref.onDispose(engine.dispose);
  return engine;
});

/// Связь с АТС — для строки состояния на экране набора.
class LinkController extends Notifier<LinkStatus> {
  @override
  LinkStatus build() {
    final engine = ref.watch(engineProvider);
    if (engine == null) return LinkStatus.offline;
    void sync() => state = engine.link.value;
    engine.link.addListener(sync);
    ref.onDispose(() => engine.link.removeListener(sync));
    return engine.link.value;
  }
}

final linkProvider = NotifierProvider<LinkController, LinkStatus>(LinkController.new);

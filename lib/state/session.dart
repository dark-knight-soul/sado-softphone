import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/call_keeper.dart';
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
    await _forgetPush();
    final p = ref.read(prefsProvider);
    await p.remove(_kServer);
    await p.remove(_kNumber);
    // История звонков — личные данные: при выходе стираем (ключ тот же, что в history.dart).
    await p.remove('history');
    await ref.read(passwordStoreProvider).clear();
    _engine = null;
    state = null;
  }

  /// Отдаёт движок для учётной записи: готовый после входа или новый — при запуске приложения
  /// с сохранённой учётной записью (тогда он подключается сам, в фоне).
  CallEngine takeEngine(Account account) {
    final ready = _ready;
    if (ready != null) {
      _ready = null;
      _engine = ready;
      return ready;
    }
    final engine = ref.read(engineFactoryProvider)(account);
    _engine = engine;
    unawaited(_connectSaved(engine, account));
    return engine;
  }

  /// Подключение, которое идёт прямо сейчас (или последнее завершённое). Нужен, чтобы смена режима
  /// «будить по звонку» не начинала второе подключение поверх первого.
  Future<void>? _connecting;

  Future<void> _connectSaved(CallEngine engine, Account account) {
    final running = _connect(engine, account);
    _connecting = running;
    return running;
  }

  Future<void> _connect(CallEngine engine, Account account) async {
    try {
      final password = account.isDemo ? '' : await ref.read(passwordStoreProvider).read();
      if (password == null) {
        // Пароля в хранилище нет (например, данные приложения очищены) — просим войти заново.
        await signOut();
        return;
      }
      final push = await _pushToUse(account);
      _push = push;
      await engine.connect(account, password, keepTrying: true, push: push);
    } catch (_) {
      // Движок мог быть уже закрыт (человек вышел, пока шло подключение) — это не ошибка.
    }
  }

  // ---- Режим «будить по звонку» ----

  /// Движок текущей учётной записи — тот, что отдан [engineProvider]. Спрашивать его у самого
  /// [engineProvider] отсюда нельзя: тот зависит от этого класса, получился бы замкнутый круг.
  CallEngine? _engine;

  /// С какими сведениями о push движок подключён сейчас (null — без них, обычный режим).
  PushInfo? _push;

  /// Сведения о push для подключения: только если режим выбран в настройках и push на телефоне есть.
  Future<PushInfo?> _pushToUse(Account account) async {
    final settings = ref.read(settingsProvider);
    if (account.isDemo || !settings.backgroundLink || !settings.pushWake) return null;
    try {
      return await ref.read(callKeeperProvider).pushInfo().timeout(const Duration(seconds: 4));
    } catch (_) {
      return null; // телефон не ответил — подключаемся как обычно
    }
  }

  /// Уйти со связи до push или до открытия приложения. Во время звонка движок это не выполняет.
  Future<void> sleep() async {
    try {
      await _engine?.sleep();
    } catch (_) {
      // Движок уже закрыт.
    }
  }

  /// Вернуться на связь после сна. Если связь уже есть или устанавливается — ничего не делает.
  Future<void> wake() async {
    final engine = _engine;
    final account = state;
    if (engine == null || account == null) return;
    final link = engine.link.value.state;
    if (link == LinkState.online || link == LinkState.connecting) return;
    await _connectSaved(engine, account);
  }

  /// Режим включили, выключили или сменился адрес телефона: АТС должна узнать новые сведения о push
  /// (или что их больше нет). Для этого регистрируемся заново — уже с ними или без них.
  Future<void> usePush(PushInfo? push) async {
    // Дожидаемся подключения, которое уже идёт: возможно, оно как раз и несёт нужные сведения.
    await _connecting;
    final engine = _engine;
    final account = state;
    if (engine == null || account == null || account.isDemo || push == _push) return;
    if (engine.call.value != null || engine.other.value != null) return; // во время звонка связь не трогаем
    await sleep();
    await _connectSaved(engine, account);
  }

  /// Перед выходом из учётной записи: если АТС знает, как будить этот телефон, регистрируемся «по-обычному»,
  /// чтобы она это забыла, — иначе она продолжала бы будить телефон, на котором уже никто не вошёл.
  Future<void> _forgetPush() async {
    if (_push == null) return;
    _push = null;
    final account = state;
    if (account == null) return;
    try {
      final engine = _engine;
      final password = await ref.read(passwordStoreProvider).read();
      if (engine == null || password == null) return;
      await engine.sleep();
      await engine.connect(account, password).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Не вышло (нет сети) — выходим всё равно; АТС перестанет будить, когда не дождётся регистрации.
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

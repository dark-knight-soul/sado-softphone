import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Где лежит пароль от номера. Отдельный класс, чтобы в тестах подменять хранилище на память.
abstract class PasswordStore {
  Future<String?> read();

  Future<void> write(String password);

  Future<void> clear();
}

/// Защищённое хранилище телефона: на Android пароль шифруется ключом из Keystore,
/// который не покидает устройство. В обычные настройки приложения пароль не попадает.
class SecurePasswordStore implements PasswordStore {
  const SecurePasswordStore();

  static const _key = 'account.password';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String password) => _storage.write(key: _key, value: password);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Хранилище в памяти — для тестов.
class MemoryPasswordStore implements PasswordStore {
  MemoryPasswordStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String password) async => value = password;

  @override
  Future<void> clear() async => value = null;
}

final passwordStoreProvider = Provider<PasswordStore>((ref) => const SecurePasswordStore());

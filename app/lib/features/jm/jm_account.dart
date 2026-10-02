import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JM 账号的本地加密存储（flutter_secure_storage，与桶凭证同等待遇）。
class JmAccountStore {
  JmAccountStore._();

  static const _kUser = 'jm.username';
  static const _kPass = 'jm.password';
  static const _storage = FlutterSecureStorage();

  static Future<(String, String)?> read() async {
    final u = await _storage.read(key: _kUser);
    final p = await _storage.read(key: _kPass);
    if (u == null || u.isEmpty || p == null || p.isEmpty) return null;
    return (u, p);
  }

  static Future<void> save(String username, String password) async {
    await _storage.write(key: _kUser, value: username);
    await _storage.write(key: _kPass, value: password);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _kUser);
    await _storage.delete(key: _kPass);
  }
}

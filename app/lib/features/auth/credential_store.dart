import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../bucket/bucket_config.dart';
import 'pin_crypto.dart';

/// 凭证存储抽象。实现基于平台安全存储（Android Keystore / Windows DPAPI）。
abstract class CredentialStore {
  Future<bool> hasPin();
  Future<void> savePin(String pin);
  Future<bool> verifyPin(String pin);

  /// 非机密连接参数（endpoint/port/region/bucket/AK）。
  Future<BucketConfig?> readBucketConfig();
  Future<void> saveBucketConfig(BucketConfig config);

  /// SK 经 PIN 派生密钥加密后存储。
  Future<String?> readSecretKey(String pin);
  Future<void> saveSecretKey(String secretKey, String pin);

  Future<void> clear();
}

/// 用固定探针明文校验 PIN：能解密即正确，无需单独存盐。
const _pinProbe = 'mandu-reader/pin-probe/v1';

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([this._storage = const FlutterSecureStorage()]);

  static const _keyPinProbe = 'pin_probe';
  static const _keyBucketConfig = 'bucket_config';
  static const _keySecretKey = 'encrypted_sk';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasPin() async {
    return await _storage.containsKey(key: _keyPinProbe);
  }

  @override
  Future<void> savePin(String pin) async {
    await _storage.write(
      key: _keyPinProbe,
      value: PinCrypto.encrypt(_pinProbe, pin),
    );
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final payload = await _storage.read(key: _keyPinProbe);
    if (payload == null) return false;
    try {
      return PinCrypto.decrypt(payload, pin) == _pinProbe;
    } on PinMismatchException {
      return false;
    }
  }

  @override
  Future<BucketConfig?> readBucketConfig() async {
    final raw = await _storage.read(key: _keyBucketConfig);
    if (raw == null) return null;
    return BucketConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveBucketConfig(BucketConfig config) async {
    await _storage.write(
      key: _keyBucketConfig,
      value: jsonEncode(config.toJson()),
    );
  }

  @override
  Future<String?> readSecretKey(String pin) async {
    final payload = await _storage.read(key: _keySecretKey);
    if (payload == null) return null;
    return PinCrypto.decrypt(payload, pin);
  }

  @override
  Future<void> saveSecretKey(String secretKey, String pin) async {
    await _storage.write(
      key: _keySecretKey,
      value: PinCrypto.encrypt(secretKey, pin),
    );
  }

  @override
  Future<void> clear() => _storage.deleteAll();
}

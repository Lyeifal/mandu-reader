import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bucket/bucket_config.dart';
import '../providers.dart';

enum AuthPhase { needsSetup, locked, unlocked }

class AuthState {
  const AuthState(this.phase, {this.pin});

  final AuthPhase phase;

  /// 仅存活于内存的 PIN，用于派生密钥解 SK。锁屏即清空。
  final String? pin;

  bool get isUnlocked => phase == AuthPhase.unlocked;
}

/// 认证门控：首次设置 PIN → 解锁校验 → 内存持有 PIN。
class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final store = ref.watch(credentialStoreProvider);
    final has = await store.hasPin();
    return AuthState(has ? AuthPhase.locked : AuthPhase.needsSetup);
  }

  Future<void> setupPin(String pin) async {
    await ref.read(credentialStoreProvider).savePin(pin);
    state = AsyncData(AuthState(AuthPhase.unlocked, pin: pin));
  }

  /// 返回是否解锁成功。
  Future<bool> unlock(String pin) async {
    final ok = await ref.read(credentialStoreProvider).verifyPin(pin);
    if (ok) {
      state = AsyncData(AuthState(AuthPhase.unlocked, pin: pin));
    }
    return ok;
  }

  /// 指纹解锁：系统生物识别通过后取回 PIN 副本，走正常校验。
  /// 返回是否解锁成功。
  Future<bool> unlockWithBiometric() async {
    final store = ref.read(credentialStoreProvider);
    final pin = await store.readBiometricPin();
    if (pin == null) return false;
    return unlock(pin);
  }

  /// 启用指纹解锁（须处于已解锁状态，用内存中的 PIN 存副本）。
  Future<void> enableBiometric() async {
    final pin = state.value?.pin;
    if (pin == null) throw StateError('未解锁，无法启用指纹解锁');
    await ref.read(credentialStoreProvider).saveBiometricPin(pin);
  }

  Future<void> disableBiometric() =>
      ref.read(credentialStoreProvider).clearBiometricPin();

  Future<bool> isBiometricEnabled() =>
      ref.read(credentialStoreProvider).hasBiometricPin();

  Future<void> lock() async {
    final has = await ref.read(credentialStoreProvider).hasPin();
    state = AsyncData(AuthState(has ? AuthPhase.locked : AuthPhase.needsSetup));
  }
}

/// 桶配置生命周期：读 → 存 → 用 PIN 解出 SK 组成生效配置。
class BucketConfigController extends AsyncNotifier<BucketConfig?> {
  @override
  Future<BucketConfig?> build() => _load();

  Future<BucketConfig?> _load() async {
    final store = ref.watch(credentialStoreProvider);
    final base = await store.readBucketConfig();
    if (base == null) return null;
    final pin = ref.watch(authControllerProvider).value?.pin;
    if (pin == null) return base;
    try {
      final sk = await store.readSecretKey(pin);
      return base.copyWith(secretKey: sk ?? '');
    } on Object {
      // 存储损坏（非 JSON/缺字段/坏 base64）时保持可用状态：
      // SK 为空 → 客户端不可用，由设置页重新保存修复，而不是整页报错。
      return base;
    }
  }

  Future<void> save(BucketConfig config) async {
    final pin = ref.read(authControllerProvider).value?.pin;
    if (pin == null) {
      throw StateError('未解锁，无法保存需要加密的凭证');
    }
    final store = ref.read(credentialStoreProvider);
    await store.saveBucketConfig(config);
    var sk = config.secretKey;
    if (sk.isNotEmpty) {
      await store.saveSecretKey(sk, pin);
    } else {
      // 表单「留空 = 不修改」：状态里必须合并回已存储的 SK，
      // 否则保存一次设置后 bucketClientProvider 因 secretKey 为空而失效。
      sk = await store.readSecretKey(pin) ?? '';
    }
    state = AsyncData(config.copyWith(secretKey: sk));
  }
}

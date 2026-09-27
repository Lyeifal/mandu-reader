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
    final sk = await store.readSecretKey(pin);
    return base.copyWith(secretKey: sk ?? '');
  }

  Future<void> save(BucketConfig config) async {
    final pin = ref.read(authControllerProvider).value?.pin;
    if (pin == null) {
      throw StateError('未解锁，无法保存需要加密的凭证');
    }
    final store = ref.read(credentialStoreProvider);
    await store.saveBucketConfig(config);
    if (config.secretKey.isNotEmpty) {
      await store.saveSecretKey(config.secretKey, pin);
    }
    state = AsyncData(config);
  }
}

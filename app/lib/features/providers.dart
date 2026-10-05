import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import 'auth/auth_controller.dart';
import 'auth/credential_store.dart';
import 'bucket/bucket_client.dart';
import 'bucket/bucket_config.dart';
import 'bucket/minio_bucket_client.dart';
import 'settings/settings_repository.dart';

/// 在 main() 中以 overrideWithValue 注入实现。
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => throw UnimplementedError('credentialStoreProvider 需在 main() 注入'),
);

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider 需在 main() 注入'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// 生效的桶配置（含 SK；未解锁时 SK 为空 → 客户端不可用）。
final bucketConfigControllerProvider =
    AsyncNotifierProvider<BucketConfigController, BucketConfig?>(
      BucketConfigController.new,
    );

final bucketClientProvider = Provider<BucketClient?>((ref) {
  final cfg = ref.watch(bucketConfigControllerProvider).value;
  if (cfg == null || cfg.secretKey.isEmpty) return null;
  try {
    final client = MinioBucketClient(cfg);
    ref.onDispose(client.close);
    return client;
  } on Object {
    return null;
  }
});

/// 根 ProviderContainer：main() 显式创建后赋值。
/// 用在「没有 context、也不在 provider build 内」的入口——
/// 目前仅 JM 任务恢复：闪退/被杀后把中断的下载自动续跑。
/// 测试里不赋值则为 null，恢复逻辑跳过续跑（清扫仍执行）。
ProviderContainer? rootContainer;

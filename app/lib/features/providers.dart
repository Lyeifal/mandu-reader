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
    return MinioBucketClient(cfg);
  } on Object {
    return null;
  }
});

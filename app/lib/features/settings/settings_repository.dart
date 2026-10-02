import 'package:drift/drift.dart';

import '../../data/db/app_database.dart';

/// 设置读写（设计文档 §10）。DB 优先，缺省回退 [defaults]。
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// M1 先落最常用的默认值，其余随里程碑补充。
  static const defaults = <String, String>{
    'reader.manga.autoPageIntervalSeconds': '5',
    'reader.manga.scrollPercent': '92',
    'reader.manga.mode': 'vertical',
    'reader.manga.snap': 'false',
    'reader.manga.doublePage': 'false',
    'reader.novel.themePreset': 'day',
    'reader.novel.fontSizePx': '16',
    'reader.novel.lineHeight': '1.6',
    'reader.novel.paging': 'scroll',
    'reader.brightness': '1.0',
    'cache.imageLimitMb': '2048',
    'cache.autoUpdateOnWifi': 'false',
    'storage.local_dir': '',
  };

  Future<String?> get(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value ?? defaults[key];
  }

  Future<void> set(String key, String value, {bool synced = false}) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(
            key: Value(key),
            value: Value(value),
            scope: Value(synced ? 'synced' : 'device'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Stream<Map<String, String>> watchAll() {
    return (_db.select(_db.settings)).watch().map((rows) {
      final map = Map<String, String>.of(defaults);
      for (final r in rows) {
        map[r.key] = r.value;
      }
      return map;
    });
  }
}

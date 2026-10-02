import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Works, Bookmarks, ReadingProgress, Settings, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'mandu_reader'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // FTS5 虚表（设计文档 §9）。不走 drift 代码生成：
      // drift_dev 对 drift 文件的虚表解析需要额外注册 fts5 模块，
      // 运行时建表更简单可靠；查询层统一走 customStatement。
      await customStatement(
        "CREATE VIRTUAL TABLE IF NOT EXISTS works_fts USING fts5("
        "id, title, title_jp, author, series, tags, tokenize = 'trigram')",
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2：中文与汉化质量、发布/完结时间（筛选用）
        await m.addColumn(works, works.hasZh);
        await m.addColumn(works, works.zhQuality);
        await m.addColumn(works, works.publishedAt);
        await m.addColumn(works, works.completedAt);
      }
    },
  );
}

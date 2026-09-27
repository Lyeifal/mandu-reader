import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../data/db/app_database.dart';
import '../bucket/bucket_client.dart';
import '../bucket/path_helper.dart';
import 'works_index.dart';

final _log = Logger('IndexSync');

class SyncReport {
  const SyncReport({
    required this.upserted,
    required this.badLines,
    required this.byteOffset,
    this.upToDate = false,
  });

  /// 写入/覆盖的行数。
  final int upserted;
  final List<BadLine> badLines;

  /// 同步后的字节水位（= 对象大小）。
  final int byteOffset;

  /// etag 未变化，未做任何事。
  final bool upToDate;
}

/// works.jsonl 同步器（设计文档 §11 M1）。
///
/// 策略：HEAD 取 etag → 未变即返回；变了整文件拉取，逐行按 id 幂等合并入库
/// （同 id 覆盖，未在文件中的本地行不受影响——local_only 作品因此安全）。
///
/// 为什么是整文件而不是字节区间增量：字节水位无法感知已消费区段的
/// 同长度改写（曾因此丢更新），而 works.jsonl 为单人单写入者的追加/覆盖
/// 日志，体量在 MB 级，整拉一次的带宽可忽略。字节级增量留作 M7 调优项
/// （届时由写入者在文件头携带 generation 号，变化即全量）。
class IndexSync {
  IndexSync({required this.db, required this.client});

  final AppDatabase db;
  final BucketClient client;

  static const syncStateName = 'works_index';

  Future<SyncReport> sync() async {
    final meta = await client.stat(LibraryPaths.worksIndex);
    final state = await _state();
    if (state?.etag != null && state!.etag == meta.etag) {
      return SyncReport(
        upserted: 0,
        badLines: const [],
        byteOffset: state.byteOffset,
        upToDate: true,
      );
    }

    final body = await client.getAll(LibraryPaths.worksIndex);
    final parsed = parseWorksIndex(utf8.decode(body, allowMalformed: false));
    await db.transaction(() async {
      for (final e in parsed.entries) {
        await _upsertWork(e, meta.etag);
      }
      await _saveWatermark(
        byteOffset: body.length,
        lineCount: parsed.entries.length,
        etag: meta.etag,
      );
    });
    _log.info(
      'sync: ${parsed.entries.length} upserts, '
      '${parsed.badLines.length} bad lines',
    );
    return SyncReport(
      upserted: parsed.entries.length,
      badLines: parsed.badLines,
      byteOffset: body.length,
    );
  }

  Future<SyncStateData?> _state() => (db.select(
    db.syncState,
  )..where((t) => t.name.equals(syncStateName))).getSingleOrNull();

  Future<void> _upsertWork(WorksIndexEntry e, String? etag) async {
    await db
        .into(db.works)
        .insertOnConflictUpdate(
          WorksCompanion(
            id: Value(e.id),
            type: Value(e.type),
            title: Value(e.title),
            titleJp: Value(e.titleJp),
            author: Value(e.author),
            series: Value(e.series),
            volume: Value(e.volume),
            tags: Value(jsonEncode(e.tags)),
            status: Value(e.status),
            totalChars: Value(e.totalChars),
            pages: Value(e.pages),
            lastUpdated: Value(e.lastUpdated),
            cover: Value(e.cover),
            origin: Value(e.origin),
            localOnly: Value(e.localOnly),
            etag: Value(etag),
            syncedAt: Value(DateTime.now()),
          ),
        );
    await db.customStatement('DELETE FROM works_fts WHERE id = ?', [e.id]);
    await db.customStatement(
      'INSERT INTO works_fts (id, title, title_jp, author, series, tags) '
      'VALUES (?,?,?,?,?,?)',
      [e.id, e.title, e.titleJp, e.author, e.series, e.tags.join(' ')],
    );
  }

  Future<void> _saveWatermark({
    required int byteOffset,
    required int lineCount,
    required String? etag,
  }) async {
    await db
        .into(db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion(
            name: const Value(syncStateName),
            byteOffset: Value(byteOffset),
            lineCount: Value(lineCount),
            etag: Value(etag),
            syncedAt: Value(DateTime.now()),
          ),
        );
  }
}

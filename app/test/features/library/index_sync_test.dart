import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/core/exceptions.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/bucket/bucket_client.dart';
import 'package:mandu_reader/features/bucket/path_helper.dart';
import 'package:mandu_reader/features/library/index_sync.dart';
import 'package:path/path.dart' as p;

/// 内存假桶：key → bytes + 单调递增 etag，模拟 S3 对象语义。
class FakeBucketClient implements BucketClient {
  final objects = <String, Uint8List>{};
  final etags = <String, String>{};
  var _etagCounter = 0;

  void seed(String key, String content) {
    objects[key] = Uint8List.fromList(utf8.encode(content));
    etags[key] = 'etag-${++_etagCounter}';
  }

  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      const ConnectivityResult(ok: true, latencyMs: 1, detail: 'fake');

  @override
  Future<ObjectMeta> stat(String key) async {
    final data = objects[key];
    if (data == null) throw ObjectNotFoundException(key);
    return ObjectMeta(size: data.length, etag: etags[key]);
  }

  @override
  Future<Uint8List> getRange(String key, {int? start, int? end}) async {
    final data = objects[key];
    if (data == null) throw ObjectNotFoundException(key);
    final s = start ?? 0;
    final e = (end ?? data.length).clamp(0, data.length);
    return Uint8List.fromList(data.sublist(s, e));
  }

  @override
  Future<Uint8List> getAll(String key) => getRange(key);

  @override
  Future<void> put(String key, Uint8List data) async {
    objects[key] = data;
    etags[key] = 'etag-${++_etagCounter}';
  }

  @override
  Future<String> presignGet(
    String key, {
    Duration ttl = const Duration(minutes: 5),
  }) async => 'https://fake/$key';

  @override
  Future<List<String>> listKeys(String prefix, {int max = 20}) async =>
      objects.keys.where((k) => k.startsWith(prefix)).take(max).toList();

  @override
  Future<void> delete(String key) async {
    objects.remove(key);
    etags.remove(key);
  }
}

Future<List<String>> ftsQuery(AppDatabase db, String term) async {
  final rows = await db
      .customSelect(
        'SELECT id FROM works_fts WHERE works_fts MATCH ?',
        variables: [Variable.withString(term)],
      )
      .get();
  return rows.map((r) => r.read<String>('id')).toList();
}

Future<SyncStateData> watermark(AppDatabase db) => (db.select(
  db.syncState,
)..where((t) => t.name.equals(IndexSync.syncStateName))).getSingle();

void main() {
  late AppDatabase db;
  late FakeBucketClient client;
  late IndexSync sync;

  const n1 =
      '{"id":"n1","type":"novel","title":"书名甲","author":"作者甲","status":"ongoing"}';
  const n2 =
      '{"id":"n2","type":"novel","title":"书名乙","author":"作者乙","status":"completed"}';
  const bad = 'this-is-not-json';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = FakeBucketClient();
    sync = IndexSync(db: db, client: client);
  });

  tearDown(() async => db.close());

  test('首次同步：坏行跳过、水位推进、FTS 可检索中文', () async {
    final content = '$n1\n$n2\n$bad\n';
    client.seed(LibraryPaths.worksIndex, content);

    final report = await sync.sync();

    expect(report.upserted, 2);
    expect(report.badLines.length, 1);
    expect(report.byteOffset, utf8.encode(content).length);

    final works = await db.select(db.works).get();
    expect(works.length, 2);
    expect(works.map((w) => w.id), containsAll(['n1', 'n2']));

    final wm = await watermark(db);
    expect(wm.byteOffset, utf8.encode(content).length);
    expect(wm.lineCount, 2);

    expect(await ftsQuery(db, '书名甲'), ['n1']);
    expect(await ftsQuery(db, '作者乙'), ['n2']);
  });

  test('etag 未变化时 upToDate，零写入', () async {
    client.seed(LibraryPaths.worksIndex, '$n1\n');
    await sync.sync();
    final report = await sync.sync();
    expect(report.upToDate, isTrue);
    expect(report.upserted, 0);
  });

  test('追加新行：按 id 合并，无重复行', () async {
    client.seed(LibraryPaths.worksIndex, '$n1\n$n2\n');
    await sync.sync();

    const n3 = '{"id":"n3","type":"manga","title":"画名丙","pages":42}';
    final newContent = '$n1\n$n2\n$n3\n';
    client.seed(LibraryPaths.worksIndex, newContent); // 新 etag

    final report = await sync.sync();

    expect(report.upserted, 3); // 幂等合并 3 行
    final works = await db.select(db.works).get();
    expect(works.length, 3); // 无重复
    expect(await ftsQuery(db, '画名丙'), ['n3']);

    final wm = await watermark(db);
    expect(wm.byteOffset, utf8.encode(newContent).length);
  });

  test('改写行：同 id 覆盖合并', () async {
    client.seed(LibraryPaths.worksIndex, '$n1\n');
    await sync.sync();

    final rewritten =
        '{"id":"n1","type":"novel","title":"改名了","author":"作者甲","status":"ongoing"}';
    client.seed(LibraryPaths.worksIndex, '$rewritten\n');

    await sync.sync();
    final work = await (db.select(
      db.works,
    )..where((t) => t.id.equals('n1'))).getSingle();
    expect(work.title, '改名了');
  });

  test('local_only 行不受桶同步影响', () async {
    client.seed(LibraryPaths.worksIndex, '$n1\n');
    await sync.sync();

    await db
        .into(db.works)
        .insertOnConflictUpdate(
          const WorksCompanion(
            id: Value('local_1'),
            type: Value('novel'),
            title: Value('本地书'),
            localOnly: Value(true),
          ),
        );

    client.seed(LibraryPaths.worksIndex, '$n1\n$n2\n');
    await sync.sync();

    final local = await (db.select(
      db.works,
    )..where((t) => t.id.equals('local_1'))).getSingleOrNull();
    expect(local, isNotNull);
    expect(local!.localOnly, isTrue);
  });

  test('墓碑行：删除其他设备已删除的作品（含 FTS 清理）', () async {
    client.seed(LibraryPaths.worksIndex, '$n1\n$n2\n');
    await sync.sync();
    expect(await ftsQuery(db, '书名乙'), ['n2']);

    // 模拟另一端删除云端：旧行移除 + 追加墓碑
    client.seed(LibraryPaths.worksIndex, '$n1\n{"id":"n2","deleted":true}\n');

    final report = await sync.sync();
    expect(report.upToDate, isFalse);
    final works = await db.select(db.works).get();
    expect(works.length, 1);
    expect(works.single.id, 'n1');
    expect(await ftsQuery(db, '书名乙'), isEmpty);
  });

  test('墓碑行不算坏行，且排在作品行之后也能正确删除', () async {
    client.seed(LibraryPaths.worksIndex, '{"id":"n1","deleted":true}\n$n1\n');
    final report = await sync.sync();
    expect(report.badLines, isEmpty);
    // 先按行序 upsert 再统一应用墓碑：最终 n1 被删除
    expect(await db.select(db.works).get(), isEmpty);
  });

  test('墓碑 + 本机有副本：转为仅本设备，记录与文件都保留', () async {
    final tmpRoot = await Directory.systemTemp.createTemp('mandu_tomb');
    try {
      client.seed(LibraryPaths.worksIndex, '$n1\n$n2\n');
      sync = IndexSync(
        db: db,
        client: client,
        localRootResolver: () async => tmpRoot.path,
      );
      await sync.sync();

      // 本机存有 n2 的副本
      final dir = Directory(p.join(tmpRoot.path, 'n2'))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'book.txt')).writeAsStringSync('正文');

      client.seed(LibraryPaths.worksIndex, '$n1\n{"id":"n2","deleted":true}\n');
      await sync.sync();

      final works = await db.select(db.works).get();
      expect(works.map((w) => w.id), containsAll(['n1', 'n2']));
      final kept = works.firstWhere((w) => w.id == 'n2');
      expect(kept.localOnly, isTrue);
      expect(
        await File(p.join(tmpRoot.path, 'n2', 'book.txt')).exists(),
        isTrue,
      );
    } finally {
      await tmpRoot.delete(recursive: true);
    }
  });

  test('墓碑 + 本机只有小说阅读缓存：缓存转正为本地目录', () async {
    final tmpRoot = await Directory.systemTemp.createTemp('mandu_tomb');
    try {
      client.seed(LibraryPaths.worksIndex, '$n1\n');
      sync = IndexSync(
        db: db,
        client: client,
        localRootResolver: () async => tmpRoot.path,
      );
      await sync.sync();

      // 云端小说的阅读缓存（未转正的副本）
      final cache = Directory(p.join(tmpRoot.path, '_novel_cache', 'n1'))
        ..createSync(recursive: true);
      File(p.join(cache.path, 'book.txt')).writeAsStringSync('正文');

      client.seed(LibraryPaths.worksIndex, '$n1\n{"id":"n1","deleted":true}\n');
      await sync.sync();

      final kept = await (db.select(
        db.works,
      )..where((t) => t.id.equals('n1'))).getSingleOrNull();
      expect(kept, isNotNull);
      expect(kept!.localOnly, isTrue);
      // 缓存已移动到正式本地目录
      expect(
        await File(p.join(tmpRoot.path, 'n1', 'book.txt')).exists(),
        isTrue,
      );
      expect(
        await Directory(p.join(tmpRoot.path, '_novel_cache', 'n1')).exists(),
        isFalse,
      );
    } finally {
      await tmpRoot.delete(recursive: true);
    }
  });
}

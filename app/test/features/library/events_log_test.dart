import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/core/exceptions.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/bucket/bucket_client.dart';
import 'package:mandu_reader/features/bucket/path_helper.dart';
import 'package:mandu_reader/features/library/events_log.dart';

/// 内存假桶（与 index_sync_test 同构的精简版）。
class FakeBucketClient implements BucketClient {
  final objects = <String, Uint8List>{};

  void seed(String key, String content) {
    objects[key] = Uint8List.fromList(utf8.encode(content));
  }

  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      const ConnectivityResult(ok: true, latencyMs: 1, detail: 'fake');

  @override
  Future<ObjectMeta> stat(String key) {
    final data = objects[key];
    if (data == null) throw ObjectNotFoundException(key);
    return Future.value(ObjectMeta(size: data.length, etag: 'x'));
  }

  @override
  Future<Uint8List> getRange(String key, {int? start, int? end}) {
    final data = objects[key];
    if (data == null) throw ObjectNotFoundException(key);
    final s = start ?? 0;
    final e = (end ?? data.length).clamp(0, data.length);
    return Future.value(Uint8List.fromList(data.sublist(s, e)));
  }

  @override
  Future<Uint8List> getAll(String key) => getRange(key);

  @override
  Future<void> put(String key, Uint8List data) async {
    objects[key] = data;
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
  }
}

String line(Map<String, Object?> e) => jsonEncode(e);

DateTime t(int second) => DateTime.utc(2026, 1, 1, 0, 0, second);

void main() {
  group('parseEventsLog', () {
    test('逐行解析：空行跳过、坏行收集、snapshot 行接受', () {
      final content = [
        line({
          'ts': t(1).toIso8601String(),
          'dev': 'pc',
          'type': 'manga_progress',
          'work': 'm1',
          'loc': {'page': 3},
        }),
        '',
        'not-json',
        line({
          'ts': t(2).toIso8601String(),
          'dev': 'pc',
          'type': 'snapshot',
          'work': 'm1',
          'loc': {'page': 5},
        }),
      ].join('\n');

      final (events, bad) = parseEventsLog(content);
      expect(events.length, 2);
      expect(events[0].isProgress, isTrue);
      expect(events[1].type, 'snapshot');
      expect(bad.length, 1);
      expect(bad.single.lineNo, 3);
    });

    test('缺 ts 回退 epoch（LWW 自然输）；缺 type 视为坏行', () {
      final (events, bad) = parseEventsLog(
        '{"dev":"pc","type":"manga_progress","work":"m1"}\n{"ts":"x"}\n',
      );
      expect(events.single.ts, DateTime.fromMillisecondsSinceEpoch(0));
      expect(bad.length, 1);
    });
  });

  group('replayEvents（§5.1 合并语义）', () {
    test('progress LWW：ts 新者胜', () {
      final r = replayEvents([
        ReaderEvent(
          ts: t(1),
          dev: 'pc',
          type: 'manga_progress',
          work: 'm1',
          loc: {'page': 3},
        ),
        ReaderEvent(
          ts: t(9),
          dev: 'phone',
          type: 'manga_progress',
          work: 'm1',
          loc: {'page': 12},
        ),
      ]);
      expect(r.progress['m1']!.loc!['page'], 12);
    });

    test('ts 相同按 (dev, type) 字典序决胜', () {
      ReaderEvent ev(String dev, String type, int page) => ReaderEvent(
        ts: t(5),
        dev: dev,
        type: type,
        work: 'm1',
        loc: {'page': page},
      );
      // phone|manga_progress > pc|manga_progress
      final r = replayEvents([
        ev('phone', 'manga_progress', 8),
        ev('pc', 'manga_progress', 2),
      ]);
      expect(r.progress['m1']!.loc!['page'], 8);
      // pc|snapshot > pc|manga_progress（s > m）
      final r2 = replayEvents([
        ev('pc', 'manga_progress', 2),
        ev('pc', 'snapshot', 9),
      ]);
      expect(r2.progress['m1']!.loc!['page'], 9);
    });

    test('bookmark 同 id：ts 更新者覆盖；旧事件不改判', () {
      ReaderEvent bm(int sec, String note) => ReaderEvent(
        ts: t(sec),
        dev: 'pc',
        type: 'bookmark',
        id: 'b1',
        work: 'n1',
        loc: {'para': 1},
        note: note,
      );
      final r = replayEvents([bm(9, '新'), bm(2, '旧')]);
      expect(r.bookmarks['b1']!.note, '新');
    });

    test('delete 只删 ts 不比它新的书签；更新的书签在 delete 之后写入则复活', () {
      ReaderEvent bm(int sec) => ReaderEvent(
        ts: t(sec),
        dev: 'pc',
        type: 'bookmark',
        id: 'b1',
        work: 'n1',
        loc: {'para': 1},
      );
      ReaderEvent del(int sec) =>
          ReaderEvent(ts: t(sec), dev: 'pc', type: 'bookmark_delete', id: 'b1');

      // 删除晚于书签 → 删
      final r1 = replayEvents([bm(2), del(8)]);
      expect(r1.bookmarks, isEmpty);
      expect(r1.deletedBookmarkIds, {'b1'});
      // 删除早于书签 → 书签还在
      final r2 = replayEvents([del(2), bm(8)]);
      expect(r2.bookmarks.containsKey('b1'), isTrue);
      // 删除后再来更旧的书签 → 不复活
      final r3 = replayEvents([del(8), bm(2)]);
      expect(r3.bookmarks, isEmpty);
    });
  });

  group('appendEvents', () {
    test('首个事件容忍文件不存在；续写补换行', () async {
      final client = FakeBucketClient();
      await appendEvents(client, [
        {'type': 'manga_progress', 'work': 'm1', 'ts': t(1).toIso8601String()},
      ]);
      expect(
        utf8.decode(client.objects[LibraryPaths.eventsLog]!),
        endsWith('\n'),
      );

      // 手工去掉尾换行，再追加：应先补 \n 而不是粘连
      client.objects[LibraryPaths.eventsLog] = Uint8List.fromList(
        utf8.encode(
          utf8.decode(client.objects[LibraryPaths.eventsLog]!).trimRight(),
        ),
      );
      await appendEvents(client, [
        {'type': 'bookmark_delete', 'id': 'b1', 'ts': t(2).toIso8601String()},
      ]);
      final content = utf8.decode(client.objects[LibraryPaths.eventsLog]!);
      expect(content.split('\n').where((e) => e.isNotEmpty).length, 2);
    });
  });

  group('syncEventsFromBucket', () {
    late AppDatabase db;
    late FakeBucketClient client;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      client = FakeBucketClient();
    });

    tearDown(() async => db.close());

    test('文件不存在 → 空报告，不报错', () async {
      final report = await syncEventsFromBucket(db: db, client: client);
      expect(report.progressCount, 0);
    });

    test('重放落库：progress/书签写入，二次同步幂等', () async {
      client.seed(
        LibraryPaths.eventsLog,
        [
          line({
            'ts': t(1).toIso8601String(),
            'dev': 'pc',
            'type': 'novel_progress',
            'work': 'n1',
            'loc': {'para': 42},
          }),
          line({
            'ts': t(2).toIso8601String(),
            'dev': 'pc',
            'type': 'bookmark',
            'id': 'b1',
            'work': 'n1',
            'loc': {'para': 42},
            'note': '要点',
          }),
        ].join('\n'),
      );

      final r1 = await syncEventsFromBucket(db: db, client: client);
      expect(r1.progressCount, 1);
      expect(r1.bookmarkCount, 1);

      final progress = await (db.select(
        db.readingProgress,
      )..where((t) => t.workId.equals('n1'))).getSingle();
      expect(jsonDecode(progress.loc)['para'], 42);
      expect(progress.dev, 'pc');

      final bm = await (db.select(
        db.bookmarks,
      )..where((t) => t.id.equals('b1'))).getSingle();
      expect(bm.note, '要点');

      // 再来一次：幂等，行数不变
      final r2 = await syncEventsFromBucket(db: db, client: client);
      expect(r2.progressCount, 1);
      expect(await db.select(db.readingProgress).get(), hasLength(1));
    });

    test('本地较新的进度不被旧事件回退；delete 清掉本地书签', () async {
      // 本地已有较新进度
      await db
          .into(db.readingProgress)
          .insert(
            ReadingProgressCompanion(
              workId: const Value('n1'),
              loc: const Value('{"para":999}'),
              updatedAt: Value(t(100)),
            ),
          );
      // 本地有一枚书签，事件里要求删除
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion(
              id: const Value('b1'),
              workId: const Value('n1'),
              loc: const Value('{"para":1}'),
              createdAt: Value(t(1)),
              updatedAt: Value(t(1)),
            ),
          );
      client.seed(
        LibraryPaths.eventsLog,
        [
          line({
            'ts': t(2).toIso8601String(),
            'dev': 'pc',
            'type': 'novel_progress',
            'work': 'n1',
            'loc': {'para': 5},
          }),
          line({
            'ts': t(3).toIso8601String(),
            'dev': 'pc',
            'type': 'bookmark_delete',
            'id': 'b1',
          }),
        ].join('\n'),
      );

      final report = await syncEventsFromBucket(db: db, client: client);
      expect(report.deletedCount, 1);

      final progress = await (db.select(
        db.readingProgress,
      )..where((t) => t.workId.equals('n1'))).getSingle();
      expect(jsonDecode(progress.loc)['para'], 999); // 本地较新，保留
      expect(await db.select(db.bookmarks).get(), isEmpty);
    });
  });
}

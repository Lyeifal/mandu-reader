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
  Future<List<BucketObjectInfo>> listObjects(String prefix, {int max = 5000}) =>
      Future.value(
        objects.entries
            .where((e) => e.key.startsWith(prefix))
            .take(max)
            .map((e) => BucketObjectInfo(key: e.key, size: e.value.length))
            .toList(),
      );

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

  group('compactEvents（日志折叠）', () {
    test('进度：每 work 留决胜者，改写 snapshot 保留原始 ts/loc', () {
      final content = [
        line({
          'ts': t(1).toIso8601String(),
          'dev': 'pc',
          'type': 'manga_progress',
          'work': 'm1',
          'loc': {'page': 3},
        }),
        line({
          'ts': t(9).toIso8601String(),
          'dev': 'phone',
          'type': 'manga_progress',
          'work': 'm1',
          'loc': {'page': 12},
        }),
        line({
          'ts': t(2).toIso8601String(),
          'dev': 'pc',
          'type': 'novel_progress',
          'work': 'n1',
          'loc': {'para': 7},
        }),
      ].join('\n');

      final c = compactEvents(content);
      expect(c.progressKept, 2);
      final lines = c.content
          .trim()
          .split('\n')
          .map((l) => jsonDecode(l) as Map)
          .toList();
      // 按 work 排序：m1 在 n1 前
      final m1 = lines[0];
      expect(m1['type'], 'snapshot');
      expect(m1['work'], 'm1');
      expect(m1['loc'], {'page': 12}); // 决胜者的 loc
      expect(m1['ts'], t(9).toIso8601String()); // 保留原始 ts
      expect(m1['folded_from'], 2);
      expect(lines[1]['work'], 'n1');
    });

    test('书签：每 id 留最新状态（删除压创建；更新的创建复活）', () {
      final content = [
        line({
          'ts': t(1).toIso8601String(),
          'dev': 'pc',
          'type': 'bookmark',
          'id': 'b1',
          'work': 'n1',
          'loc': {'para': 1},
        }),
        line({
          'ts': t(5).toIso8601String(),
          'dev': 'pc',
          'type': 'bookmark_delete',
          'id': 'b1',
        }),
        line({
          'ts': t(2).toIso8601String(),
          'dev': 'pc',
          'type': 'bookmark',
          'id': 'b2',
          'work': 'n2',
          'loc': {'para': 5},
          'note': '旧',
        }),
        line({
          'ts': t(8).toIso8601String(),
          'dev': 'phone',
          'type': 'bookmark',
          'id': 'b2',
          'work': 'n2',
          'loc': {'para': 9},
          'note': '新',
        }),
      ].join('\n');

      final c = compactEvents(content);
      expect(c.bookmarksKept, 2);
      final maps = c.content
          .trim()
          .split('\n')
          .map((l) => jsonDecode(l) as Map<String, dynamic>)
          .toList();
      final b1 = maps.firstWhere((m) => m['id'] == 'b1');
      expect(b1['type'], 'bookmark_delete');
      final b2 = maps.firstWhere((m) => m['id'] == 'b2');
      expect(b2['ts'], t(8).toIso8601String());
      expect(b2['note'], '新');
    });

    test('坏行丢弃、未知类型原样保留', () {
      final content = [
        'garbage-line',
        line({
          'ts': t(1).toIso8601String(),
          'dev': 'pc',
          'type': 'mystery_future',
          'x': 1,
        }),
        line({
          'ts': t(1).toIso8601String(),
          'dev': 'pc',
          'type': 'manga_progress',
          'work': 'm1',
          'loc': {'page': 1},
        }),
      ].join('\n');

      final c = compactEvents(content);
      expect(c.badDropped, 1);
      expect(c.content, isNot(contains('garbage-line')));
      expect(c.content, contains('mystery_future'));
    });

    test('往返不变性：压缩后重放与原日志重放结果一致', () {
      final rows = <String>[
        for (var i = 0; i < 40; i++) ...[
          line({
            'ts': t(i).toIso8601String(),
            'dev': i.isEven ? 'pc' : 'phone',
            'type': 'manga_progress',
            'work': 'm${i % 5}',
            'loc': {'page': i},
          }),
          line({
            'ts': t(i).toIso8601String(),
            'dev': 'pc',
            'type': 'novel_progress',
            'work': 'n${i % 3}',
            'loc': {'para': i * 10},
          }),
        ],
        line({
          'ts': t(3).toIso8601String(),
          'dev': 'pc',
          'type': 'bookmark',
          'id': 'b1',
          'work': 'n1',
          'loc': {'para': 1},
          'note': '要点',
        }),
        line({
          'ts': t(10).toIso8601String(),
          'dev': 'phone',
          'type': 'bookmark_delete',
          'id': 'b1',
        }),
        line({
          'ts': t(7).toIso8601String(),
          'dev': 'pc',
          'type': 'bookmark',
          'id': 'b2',
          'work': 'n2',
          'loc': {'para': 9},
          'color': 'yellow',
        }),
        'bad-line',
        line({
          'ts': t(2).toIso8601String(),
          'dev': 'pc',
          'type': 'snapshot',
          'work': 'm9',
          'loc': {'page': 99},
        }),
      ];
      final original = rows.join('\n');
      final compacted = compactEvents(original);

      final before = replayEvents(parseEventsLog(original).$1);
      final after = replayEvents(parseEventsLog(compacted.content).$1);

      // 进度：work 集合相同（折叠会重排顺序，按集合比），决胜 ts/loc 一致
      expect(after.progress.keys.toSet(), before.progress.keys.toSet());
      for (final e in before.progress.entries) {
        expect(after.progress[e.key]!.ts, e.value.ts);
        expect(after.progress[e.key]!.loc.toString(), e.value.loc.toString());
      }
      // 书签：最终状态集合一致（含删除集）
      expect(after.bookmarks.keys.toSet(), before.bookmarks.keys.toSet());
      expect(after.deletedBookmarkIds, before.deletedBookmarkIds);
      for (final e in before.bookmarks.entries) {
        expect(after.bookmarks[e.key]!.ts, e.value.ts);
        expect(after.bookmarks[e.key]!.type, e.value.type);
      }
    });

    test('输出确定性：同输入必同输出（etag 稳定）', () {
      final content = [
        line({
          'ts': t(2).toIso8601String(),
          'dev': 'phone',
          'type': 'manga_progress',
          'work': 'b',
          'loc': {'page': 1},
        }),
        line({
          'ts': t(1).toIso8601String(),
          'dev': 'pc',
          'type': 'manga_progress',
          'work': 'a',
          'loc': {'page': 2},
        }),
      ].join('\n');
      expect(compactEvents(content).content, compactEvents(content).content);
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

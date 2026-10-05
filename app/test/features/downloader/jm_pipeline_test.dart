import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/core/exceptions.dart';
import 'package:mandu_reader/core/index_merge.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/bucket/bucket_client.dart';
import 'package:mandu_reader/features/bucket/path_helper.dart';
import 'package:mandu_reader/features/downloader/jm_pipeline.dart';
import 'package:path/path.dart' as p;

/// 内存假桶（只实现测试用到的最小面）。
class _FakeBucketClient implements BucketClient {
  final objects = <String, Uint8List>{};

  /// put 延迟与在飞统计：验证上传并发度（串行实现 maxInFlight 恒为 1）。
  Duration putDelay = Duration.zero;
  var inFlight = 0;
  var maxInFlight = 0;

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
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (putDelay > Duration.zero) await Future<void>.delayed(putDelay);
      objects[key] = data;
    } finally {
      inFlight--;
    }
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

void main() {
  group('mergeIndexLine（索引读-改-写纯合并）', () {
    test('同 id 旧行被滤掉、新行追加末尾：重复上传不产生重复行', () {
      final existing =
          '{"id":"a","type":"manga","title":"旧"}\n'
          '{"id":"b","type":"manga","title":"别动"}\n';
      final out = mergeIndexLine(existing, {
        'id': 'a',
        'type': 'manga',
        'title': '新',
      });
      final lines = out.trim().split('\n');
      expect(lines.length, 2);
      // 原顺序保留（b 在前），a 的新行追加在末尾
      expect(jsonDecode(lines[0])['id'], 'b');
      expect(jsonDecode(lines[1]), {'id': 'a', 'type': 'manga', 'title': '新'});
    });

    test('坏行原样保留（重放端负责跳过）', () {
      final out = mergeIndexLine('not-json\n', {'id': 'a'});
      expect(out, startsWith('not-json'));
      expect(out.trim().split('\n').length, 2);
    });

    test('空索引直接追加', () {
      final out = mergeIndexLine('', {'id': 'a'});
      expect(out.trim().split('\n'), ['{"id":"a"}']);
    });
  });

  group('uploadNovel', () {
    late AppDatabase db;
    late _FakeBucketClient client;
    late Directory root;

    const workRow = WorksCompanion(
      id: Value('novel_1'),
      type: Value('novel'),
      title: Value('测试书'),
      author: Value('作者甲'),
      tags: Value('[]'),
      status: Value('completed'),
      localOnly: Value(true),
      origin: Value('manual'),
      cover: Value('cover.jpg'),
    );

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      client = _FakeBucketClient();
      client.seed(LibraryPaths.worksIndex, '\n');
      root = await Directory.systemTemp.createTemp('mandu_upload');
      final dir = Directory(p.join(root.path, 'novel_1'))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'book.txt')).writeAsStringSync('正文' * 100);
      File(p.join(dir.path, 'chapters.json')).writeAsStringSync(
        jsonEncode([
          {'title': '第一章', 'para': 0},
        ]),
      );
      File(p.join(dir.path, 'cover.jpg'))
          .writeAsBytesSync(List.filled(64, 0xFF));
      await db.into(db.works).insert(workRow);
    });

    tearDown(() async {
      await db.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('book.txt/封面/章节表传桶，索引行带 total_chars，行转非本地', () async {
      // 预置云端阅读缓存：上传成功后应被失效（清目录），下次打开重拉
      final cacheDir = Directory(p.join(root.path, '_novel_cache', 'novel_1'))
        ..createSync(recursive: true);
      File(p.join(cacheDir.path, 'book.txt')).writeAsStringSync('旧缓存内容');

      final pipeline = JmPipeline(localRoot: root.path);
      await pipeline.uploadNovel(
        db: db,
        client: client,
        work: await (db.select(
          db.works,
        )..where((t) => t.id.equals('novel_1'))).getSingle(),
        onProgress: (_) {},
      );

      final dir = LibraryPaths.novelDir(author: '作者甲', title: '测试书');
      expect(client.objects.containsKey('$dir/book.txt'), isTrue);
      expect(client.objects.containsKey('$dir/cover.jpg'), isTrue);
      expect(client.objects.containsKey('$dir/chapters.json'), isTrue);
      expect(cacheDir.existsSync(), isFalse);

      final indexLines = utf8
          .decode(client.objects[LibraryPaths.worksIndex]!)
          .trim()
          .split('\n');
      final entry = jsonDecode(indexLines.single) as Map<String, dynamic>;
      expect(entry['id'], 'novel_1');
      expect(entry['type'], 'novel');
      expect(entry['total_chars'], 200); // '正文' * 100
      expect(entry['local_only'], isFalse);
      expect(entry['cover'], '$dir/cover.jpg');

      final row = await (db.select(
        db.works,
      )..where((t) => t.id.equals('novel_1'))).getSingle();
      expect(row.localOnly, isFalse);
    });

    test('缺 book.txt 直接失败，不碰桶', () async {
      final dir = Directory(p.join(root.path, 'novel_1'));
      File(p.join(dir.path, 'book.txt')).deleteSync();
      await expectLater(
        JmPipeline(localRoot: root.path).uploadNovel(
          db: db,
          client: client,
          work: await (db.select(
            db.works,
          )..where((t) => t.id.equals('novel_1'))).getSingle(),
          onProgress: (_) {},
        ),
        throwsA(isA<StateError>()),
      );
      // 索引未被写入
      expect(
        utf8.decode(client.objects[LibraryPaths.worksIndex]!).trim(),
        isEmpty,
      );
    });
  });

  group('upload（漫画页面并发上传）', () {
    late AppDatabase db;
    late _FakeBucketClient client;
    late Directory root;

    const pageCount = 8;

    const workRow = WorksCompanion(
      id: Value('manga_1'),
      type: Value('manga'),
      title: Value('测试漫'),
      author: Value('作者乙'),
      tags: Value('[]'),
      status: Value('completed'),
      localOnly: Value(true),
      origin: Value('manual'),
    );

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      client = _FakeBucketClient()
        ..putDelay = const Duration(milliseconds: 5)
        ..seed(LibraryPaths.worksIndex, '\n');
      root = await Directory.systemTemp.createTemp('mandu_upload');
      final dir = Directory(p.join(root.path, 'manga_1'))
        ..createSync(recursive: true);
      for (var i = 1; i <= pageCount; i++) {
        File(p.join(dir.path, '${i.toString().padLeft(3, '0')}.jpg'))
            .writeAsBytesSync(List.filled(32, i));
      }
      await db.into(db.works).insert(workRow);
    });

    tearDown(() async {
      await db.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('页面+cover 传桶、索引行写 pages、行转非本地；并发有界且生效', () async {
      final phases = <String>[];
      final pipeline = JmPipeline(localRoot: root.path);
      final bucketDir = await pipeline.upload(
        db: db,
        client: client,
        work: await (db.select(
          db.works,
        )..where((t) => t.id.equals('manga_1'))).getSingle(),
        onProgress: phases.add,
      );

      // 每页内容按序落桶 + 封面 = 第一页
      for (var i = 1; i <= pageCount; i++) {
        expect(
          client.objects[LibraryPaths.mangaPage(bucketDir, i, ext: 'jpg')],
          List.filled(32, i),
        );
      }
      expect(client.objects['$bucketDir/cover.jpg'], List.filled(32, 1));

      final entry = jsonDecode(
        utf8.decode(client.objects[LibraryPaths.worksIndex]!).trim(),
      ) as Map<String, dynamic>;
      expect(entry['id'], 'manga_1');
      expect(entry['pages'], pageCount);
      expect(entry['local_only'], isFalse);
      expect(entry['compressed'], isFalse); // 原图 jpg 未压
      expect(entry['cover'], '$bucketDir/cover.jpg');

      final row = await (db.select(
        db.works,
      )..where((t) => t.id.equals('manga_1'))).getSingle();
      expect(row.localOnly, isFalse);
      expect(row.cover, '$bucketDir/cover.jpg');

      // 并发回归防线：串行实现 maxInFlight 恒为 1；放开并发则封顶 uploadConcurrency
      expect(client.maxInFlight, greaterThan(1));
      expect(
        client.maxInFlight,
        lessThanOrEqualTo(JmPipeline.uploadConcurrency),
      );

      // 进度按完成数 1..N 各报一次（乱序完成，按集合比）
      final reported = phases
          .where((m) => m.startsWith('上传 ') && m.endsWith(' 到桶…'))
          .map((m) => int.parse(m.split(' ')[1].split('/').first))
          .toSet();
      expect(reported, {for (var i = 1; i <= pageCount; i++) i});
    });
  });
}

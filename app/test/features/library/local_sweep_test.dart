import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/library/local_sweep.dart';
import 'package:path/path.dart' as p;

void main() {
  group('classifyLocalWork（纯判定）', () {
    test('目录不存在：移除（闪退留下的半成品行）', () {
      expect(
        classifyLocalWork(
          type: 'manga',
          dirExists: false,
          imageCount: 0,
          hasBookTxt: false,
          halfRegistered: false,
        ),
        LocalWorkFix.remove,
      );
    });

    test('漫画无图 / 小说无 book.txt：移除', () {
      expect(
        classifyLocalWork(
          type: 'manga',
          dirExists: true,
          imageCount: 0,
          hasBookTxt: false,
          halfRegistered: true,
        ),
        LocalWorkFix.remove,
      );
      expect(
        classifyLocalWork(
          type: 'novel',
          dirExists: true,
          imageCount: 0,
          hasBookTxt: false,
          halfRegistered: false,
        ),
        LocalWorkFix.remove,
      );
    });

    test('文件健在但行是半成品（pages=0/无封面）：修复', () {
      expect(
        classifyLocalWork(
          type: 'manga',
          dirExists: true,
          imageCount: 20,
          hasBookTxt: false,
          halfRegistered: true,
        ),
        LocalWorkFix.repair,
      );
    });

    test('行与文件都完整：保留', () {
      expect(
        classifyLocalWork(
          type: 'manga',
          dirExists: true,
          imageCount: 20,
          hasBookTxt: false,
          halfRegistered: false,
        ),
        LocalWorkFix.keep,
      );
      expect(
        classifyLocalWork(
          type: 'novel',
          dirExists: true,
          imageCount: 0,
          hasBookTxt: true,
          halfRegistered: false,
        ),
        LocalWorkFix.keep,
      );
    });
  });

  group('sweepDanglingLocalWorks（drift 内存库 + 临时目录）', () {
    late AppDatabase db;
    late Directory root;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      root = await Directory.systemTemp.createTemp('mandu_sweep');
    });

    tearDown(() async {
      await db.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> insertLocal({
      required String id,
      required String type,
      int? pages,
      String? cover,
    }) => db
        .into(db.works)
        .insert(
          WorksCompanion(
            id: Value(id),
            type: Value(type),
            title: Value(id),
            tags: const Value('[]'),
            pages: Value(pages),
            cover: Value(cover),
            localOnly: const Value(true),
          ),
        );

    test('目录缺失的半成品行被移除（含书签/进度连带清）', () async {
      await insertLocal(id: 'jm_1', type: 'manga', pages: 0, cover: '');
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion(
              id: const Value('bm_1'),
              workId: const Value('jm_1'),
              loc: const Value('{"page":1}'),
              createdAt: Value(DateTime(2026)),
              updatedAt: Value(DateTime(2026)),
            ),
          );

      final r = await sweepDanglingLocalWorks(db, root.path, activeWorkIds: {});
      expect(r.removed, 1);
      expect(r.repaired, 0);
      expect(await (db.select(db.works)).get(), isEmpty);
      expect(await (db.select(db.bookmarks)).get(), isEmpty);
    });

    test('进行中的下载任务（activeWorkIds）不被误删', () async {
      await insertLocal(id: 'jm_2', type: 'manga', pages: 0, cover: '');

      final r = await sweepDanglingLocalWorks(
        db,
        root.path,
        activeWorkIds: {'jm_2'},
      );
      expect(r.removed, 0);
      expect((await (db.select(db.works)).get()).single.id, 'jm_2');
    });

    test('文件健在但行半成品：补齐页数与封面', () async {
      await insertLocal(id: 'jm_3', type: 'manga', pages: 0, cover: '');
      final dir = Directory(p.join(root.path, 'jm_3'))
        ..createSync(recursive: true);
      File(p.join(dir.path, '002.jpg')).writeAsBytesSync([1]);
      File(p.join(dir.path, '001.jpg')).writeAsBytesSync([1]);

      final r = await sweepDanglingLocalWorks(db, root.path, activeWorkIds: {});
      expect(r.repaired, 1);
      final row = (await (db.select(db.works)).get()).single;
      expect(row.pages, 2);
      expect(row.cover, '001.jpg');
    });

    test('完整行不动', () async {
      await insertLocal(id: 'jm_4', type: 'manga', pages: 2, cover: '001.jpg');
      final dir = Directory(p.join(root.path, 'jm_4'))
        ..createSync(recursive: true);
      File(p.join(dir.path, '001.jpg')).writeAsBytesSync([1]);
      File(p.join(dir.path, '002.jpg')).writeAsBytesSync([1]);

      final r = await sweepDanglingLocalWorks(db, root.path, activeWorkIds: {});
      expect(r.removed + r.repaired, 0);
      expect((await (db.select(db.works)).get()).single.pages, 2);
    });

    test('小说的判定看 book.txt', () async {
      await insertLocal(id: 'n_1', type: 'novel', pages: null, cover: null);
      final dir = Directory(p.join(root.path, 'n_1'))
        ..createSync(recursive: true);
      // 只有图片没有 book.txt → 移除
      File(p.join(dir.path, 'cover.jpg')).writeAsBytesSync([1]);

      var r = await sweepDanglingLocalWorks(db, root.path, activeWorkIds: {});
      expect(r.removed, 1);

      // 补上 book.txt → 保留
      await insertLocal(id: 'n_2', type: 'novel', pages: null, cover: null);
      Directory(p.join(root.path, 'n_2')).createSync(recursive: true);
      File(p.join(root.path, 'n_2', 'book.txt')).writeAsStringSync('正文');
      r = await sweepDanglingLocalWorks(db, root.path, activeWorkIds: {});
      expect(r.removed, 0);
      expect((await (db.select(db.works)).get()).single.id, 'n_2');
    });
  });
}

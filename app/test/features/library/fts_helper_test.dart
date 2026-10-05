import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/library/fts_helper.dart';

void main() {
  group('ftsQuery（关键词 → MATCH 短语）', () {
    test('空白拆词、各词加引号 AND', () {
      expect(ftsQuery('斗破苍 仙逆凡'), '"斗破苍" "仙逆凡"');
    });

    test('剔除 FTS5 语法字符防语法错', () {
      // 运算符剔除后相邻汉字并为一个词；不足 3 字符的词丢弃
      expect(ftsQuery('斗破"苍穹'), '"斗破苍穹"');
      expect(ftsQuery('a"b*c(d)e-f:g^h'), '"abcdefgh"');
    });

    test('不足 3 字符（trigram 查询词下限，2 个汉字也匹配不到）返回 null', () {
      expect(ftsQuery('ab'), isNull);
      expect(ftsQuery('斗破'), isNull);
      expect(ftsQuery('  *  '), isNull);
    });
  });

  group('parseFilterTokens（语法糖）', () {
    test('type/tag/status/作者 前缀映射，剩余作关键词', () {
      final r = parseFilterTokens('type:novel tag:奇幻 作者:耳根 仙逆');
      expect(r.type, 'novel');
      expect(r.tag, '奇幻');
      expect(r.author, '耳根');
      expect(r.keyword, '仙逆');
      expect(r.status, isNull);
    });

    test('中文前缀与大小写不敏感', () {
      final r = parseFilterTokens('TYPE:Manga 状态:Completed');
      expect(r.type, 'manga');
      expect(r.status, 'completed');
      expect(r.keyword, isEmpty);
    });

    test('非法值忽略该 token 且不吞关键词', () {
      final r = parseFilterTokens('type:pdf 斗破');
      expect(r.type, isNull);
      expect(r.keyword, '斗破');
    });

    test('无前缀整串即关键词（冒号在词中不算前缀）', () {
      final r = parseFilterTokens('http://x');
      expect(r.keyword, 'http://x');
    });
  });

  group('upsertWorkFts（写洞公共入口）', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async => db.close());

    test('本地登记路径写入后 MATCH 即查得到（防搜索失明回归）', () async {
      await db
          .into(db.works)
          .insert(
            WorksCompanion(
              id: const Value('w1'),
              type: const Value('novel'),
              title: const Value('斗破苍穹'),
              author: const Value('天蚕土豆'),
              tags: const Value('["奇幻","热血"]'),
              status: const Value('completed'),
              origin: const Value('manual'),
              localOnly: const Value(true),
            ),
          );
      await upsertWorkFts(
        db,
        id: 'w1',
        title: '斗破苍穹',
        author: '天蚕土豆',
        tags: const ['奇幻', '热血流'],
      );

      Future<List<String>> search(String q) async {
        final match = ftsQuery(q);
        if (match == null) {
          // 生产行为回退：LIKE 查标题（2 字及以下查询毫秒级）
          final rows =
              await (db.select(db.works)
                    ..where((t) => t.title.like('%$q%'))
                    ..limit(1))
                  .get();
          return [for (final r in rows) r.id];
        }
        final rows = await db
            .customSelect(
              'SELECT id FROM works_fts WHERE works_fts MATCH ?',
              variables: [Variable(match)],
            )
            .get();
        return [for (final r in rows) r.read<String>('id')];
      }

      expect(await search('斗破苍'), ['w1']); // FTS：标题子串
      expect(await search('天蚕土'), ['w1']); // FTS：作者列
      expect(await search('热血流'), ['w1']); // FTS：标签列
      expect(await search('不存在词语'), isEmpty);
      expect(await search('斗破'), ['w1']); // 2 字 → LIKE 回退

      // 覆盖写：重复登记不产生重复行
      await upsertWorkFts(db, id: 'w1', title: '斗破苍穹 重制版');
      final rows = await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM works_fts WHERE id = ?',
            variables: const [Variable('w1')],
          )
          .getSingle();
      expect(rows.read<int>('c'), 1);
      expect(await search('重制版'), ['w1']);
    });
  });
}

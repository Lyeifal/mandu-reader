import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/reader/reader_page.dart';

void main() {
  group('searchNovel（书内搜索纯函数）', () {
    const paras = [
      '第一章 风起',
      '那是 LAN 风大的季节，Lan 处处可见，lan  never stops',
      '普通段落',
      '尾声 lan',
    ];

    test('大小写不敏感，段号与偏移按 lower 索引给出', () {
      final hits = searchNovel(paras, 'lan');
      expect(hits.map((h) => h.para).toList(), [1, 1, 1, 3]);
      expect(hits[0].offset, paras[1].toLowerCase().indexOf('lan'));
      expect(hits[0].excerpt, contains('LAN')); // 摘录取原文，保留原大小写
    });

    test('段内命中封顶 maxPerPara', () {
      final hits = searchNovel(['aa bb aa cc aa dd aa ee aa ff'], 'aa');
      expect(hits.length, 3); // 一段 5 处命中只留前 3
      expect(hits.every((h) => h.para == 0), isTrue);
    });

    test('总量封顶 maxTotal', () {
      final many = [for (var i = 0; i < 200; i++) '关键词段落 $i'];
      final hits = searchNovel(many, '关键词', maxTotal: 10);
      expect(hits.length, 10);
    });

    test('空查询与无命中都返回空表', () {
      expect(searchNovel(paras, ''), isEmpty);
      expect(searchNovel(paras, '   '), isEmpty);
      expect(searchNovel(paras, '不存在词'), isEmpty);
    });

    test('长段命中截断上下文并带省略号，excerptHitAt 指向命中词', () {
      final long = '${'垫' * 100}靶心${'垫' * 100}';
      final hits = searchNovel([long], '靶心', contextRadius: 10);
      expect(hits.length, 1);
      final hit = hits.single;
      expect(hit.excerpt.startsWith('…'), isTrue);
      expect(hit.excerpt.endsWith('…'), isTrue);
      expect(hit.excerptHitAt, 11); // 1 个前省略号 + 10 字符上文
      expect(
        hit.excerpt.substring(hit.excerptHitAt, hit.excerptHitAt + 2),
        '靶心',
      );
    });

    test('段首命中无前省略号', () {
      final hits = searchNovel(['目标在段首'], '目标');
      expect(hits.single.excerpt, '目标在段首');
      expect(hits.single.excerptHitAt, 0);
    });
  });
}

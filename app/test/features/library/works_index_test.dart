import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/library/works_index.dart';

void main() {
  group('parseWorksIndex', () {
    test('解析合法行、跳过空行与坏行', () {
      final content = '''
{"id":"n1","type":"novel","title":"书名","author":"作者","tags":["奇幻","慢热"]}

{"id":"m1","type":"manga","title":"画名","pages":42}
not-json
{"id":"bad","type":"other","title":"类型错误"}
{"type":"novel","title":"缺 id"}
''';
      final r = parseWorksIndex(content);
      expect(r.entries.length, 2);
      expect(r.entries.first.id, 'n1');
      expect(r.entries.first.tags, ['奇幻', '慢热']);
      expect(r.entries[1].pages, 42);
      expect(r.badLines.length, 3);
      expect(r.badLines.first.lineNo, 4); // not-json 在第 4 行
    });

    test('容忍缺省字段', () {
      final r = parseWorksIndex('{"id":"n1","type":"novel","title":"t"}');
      final e = r.entries.single;
      expect(e.status, 'ongoing');
      expect(e.origin, 'manual');
      expect(e.localOnly, isFalse);
      // 汉化字段缺省：有中文 + 中质量
      expect(e.hasZh, isTrue);
      expect(e.zhQuality, 'medium');
      expect(e.publishedAt, isNull);
      expect(e.completedAt, isNull);
    });

    test('汉化与发布时间字段解析，日期归一化到月', () {
      final r = parseWorksIndex(
        '{"id":"n1","type":"manga","title":"t","has_zh":false,'
        '"zh_quality":"low","published_at":"2024-03-15",'
        '"completed_at":"2025-12"}',
      );
      final e = r.entries.single;
      expect(e.hasZh, isFalse);
      expect(e.zhQuality, 'low');
      expect(e.publishedAt, '2024-03');
      expect(e.completedAt, '2025-12');
    });

    test('非法月份日期置空', () {
      final r = parseWorksIndex(
        '{"id":"n1","type":"novel","title":"t","published_at":"2024-13"}',
      );
      expect(r.entries.single.publishedAt, isNull);
    });

    test('CRLF 文件兼容', () {
      final r = parseWorksIndex(
        '{"id":"n1","type":"novel","title":"t"}\r\n{"id":"n2","type":"novel","title":"u"}\r\n',
      );
      expect(r.entries.map((e) => e.id), ['n1', 'n2']);
      expect(r.badLines, isEmpty);
    });
  });
}

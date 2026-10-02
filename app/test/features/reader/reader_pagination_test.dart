import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/reader/reader_page.dart';

void main() {
  group('novelParagraphs', () {
    test('切分全文并去重连续重复段落（早期 epub 导入的重复章标题）', () {
      final ps = novelParagraphs('序章\n\n第一章\n第一章\n\n正文');
      expect(ps, ['序章', '第一章', '正文']);
    });

    test('空行与首尾空白被忽略', () {
      expect(novelParagraphs('  a \n\n\n b '), ['a', 'b']);
    });
  });

  group('paginateNovel', () {
    // 统一参数：capacityUnits = 100/10 = 10 单位/行，
    // lineCost = 10*1.7+2 = 19，linesPerPage = 100/19 = 5
    NovelPages paginate(List<String> paras) => paginateNovel(
      paras,
      contentWidth: 100,
      contentHeight: 100,
      fontSize: 10,
    );

    test('超长段落跨页切断，内容不丢、每页不超行预算', () {
      final paras = ['a' * 500, '短'];
      final pages = paginate(paras);
      expect(pages.pages.every((p) => p.length <= 5), isTrue);
      expect(pages.pages.expand((e) => e).join(), paras.join());
    });

    test('空书保底一页', () {
      final pages = paginate(const []);
      expect(pages.length, 1);
      expect(pages.pages.single, isEmpty);
    });

    test('startParas 记录每页起始段落，pageOfPara 二分定位', () {
      final paras = List.generate(10, (i) => '段落$i');
      // capacity 6 单位：'段落0' ≈ 2.55 单位 → 每段 1 行；每页 2 行
      final pages = paginateNovel(
        paras,
        contentWidth: 60,
        contentHeight: 40,
        fontSize: 10,
      );
      expect(pages.startParas, [0, 2, 4, 6, 8]);
      expect(pages.pageOfPara(0), 0);
      expect(pages.pageOfPara(1), 0);
      expect(pages.pageOfPara(2), 1);
      expect(pages.pageOfPara(9), pages.length - 1);
    });
  });

  group('deriveChapters', () {
    test('识别 第X章/回/卷/节 形式，跳过非标题行', () {
      final ps = [
        '第一章 开端',
        '正文内容……',
        '第二节', // 「第」+「二」+「节」，合法章节标题
        '序章',
        '第十二回 风雪夜归人',
        '关于本章的说明',
        '第123章 数字章节',
      ];
      final chapters = deriveChapters(ps);
      expect(chapters.map((c) => c.para), [0, 2, 4, 6]);
      expect(chapters.first.title, '第一章 开端');
    });

    test('超过 40 字的行不算章节标题', () {
      final ps = ['第一卷 ${'很长的正文' * 8}'];
      expect(ps.single.length, greaterThan(40));
      expect(deriveChapters(ps), isEmpty);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/library/epub_import.dart';
import 'package:mandu_reader/features/reader/reader_page.dart'
    show
        NovelPages,
        dedupeConsecutive,
        deriveChapters,
        paginateNovel,
        splitParagraphs,
        wrapText;

Uint8List buildMinimalEpub() {
  final encoder = ZipEncoder();
  final archive = Archive();
  void add(String name, String content) {
    archive.addFile(
      ArchiveFile(
        name,
        content.length,
        Uint8List.fromList(utf8.encode(content)),
      ),
    );
  }

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '<?xml version="1.0"?>'
        '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  add(
    'OEBPS/content.opf',
    '<?xml version="1.0"?>'
        '<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="id">test-1</dc:identifier>'
        '<dc:title>测试邪神</dc:title>'
        '<dc:creator>无敌贱客</dc:creator>'
        '<dc:language>zh</dc:language>'
        '</metadata>'
        '<manifest>'
        '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
        '<item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>'
        '</manifest>'
        '<spine toc="ncx"><itemref idref="c1"/></spine>'
        '</package>',
  );
  add(
    'OEBPS/toc.ncx',
    '<?xml version="1.0"?>'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">'
        '<head><meta name="dtb:uid" content="test-1"/></head>'
        '<docTitle><text>测试邪神</text></docTitle>'
        '<navMap><navPoint id="n1" playOrder="1">'
        '<navLabel><text>第一章 觉醒</text></navLabel>'
        '<content src="c1.xhtml"/>'
        '</navPoint></navMap></ncx>',
  );
  add(
    'OEBPS/c1.xhtml',
    '<?xml version="1.0"?>'
        '<!DOCTYPE html>'
        '<html xmlns="http://www.w3.org/1999/xhtml">'
        '<head><title>第一章</title></head>'
        '<body>'
        '<h1>第一章 觉醒</h1>'
        '<p>云澈&amp;萧泠汐</p>'
        '<p>第二段<script>var x=1;</script>正文</p>'
        '<p>换行<br/>测试</p>'
        '</body></html>',
  );

  final zipped = encoder.encode(archive)!;
  return Uint8List.fromList(zipped);
}

void main() {
  group('paginateNovel 真实分页', () {
    // 字号 10、行高 1.7 → 行高 17px；高 100 → 每页 5 行；宽 100 → 每行 10 字宽
    NovelPages paginate(List<String> paras) => paginateNovel(
      paras,
      contentWidth: 100,
      contentHeight: 100,
      fontSize: 10,
    );

    test('行宽折行：ASCII 按 0.55 字宽计', () {
      // 18 个 ASCII ≈ 9.9 字宽 → 1 行；19 个 ≈ 10.45 → 2 行
      expect(wrapText('a' * 18, 10), hasLength(1));
      expect(wrapText('a' * 19, 10), hasLength(2));
      // 中文每字 1 字宽
      expect(wrapText('中文字符五个', 5), ['中文字符五', '个']);
    });

    test('分页内容不丢、每页不超行数、超长段跨页切断', () {
      final paras = [
        '甲' * 30, // 3 行
        '乙' * 300, // 30 行 → 跨多页
        '丙',
      ];
      final r = paginate(paras);
      // 总文本按字符拼回应与原段落拼接一致（切分只断行不断字）
      expect(r.pages.expand((e) => e).join(), paras.join());
      for (final page in r.pages) {
        expect(page.length, lessThanOrEqualTo(5));
      }
      expect(r.pages.length, greaterThan(5)); // 300 字单独就 30 行 > 5 行/页
    });

    test('pageOfPara 映射：段落所在页正确', () {
      final r = paginate(['一' * 50, '二' * 10, '三' * 10]); // 5行 + 1行 + 1行
      expect(r.pages.length, 2);
      expect(r.pageOfPara(0), 0);
      expect(r.pageOfPara(1), 1);
      expect(r.pageOfPara(2), 1);
    });
  });

  group('小说段落与章节推导', () {
    test('splitParagraphs 去空行保序', () {
      expect(splitParagraphs('甲\n\n  乙 \n丙'), ['甲', '乙', '丙']);
    });

    test('dedupeConsecutive 折叠连续重复（旧导入的重复章节标题）', () {
      expect(
        dedupeConsecutive(['第一章', '第一章', '正文', '第二章', '第二章', '第二章', '内容']),
        ['第一章', '正文', '第二章', '内容'],
      );
    });

    test('deriveChapters 识别 第X章/节/卷/回 行', () {
      const paras = ['序章', '正文一', '第一章 风起', '内容', '第二节', '第3卷'];
      final chapters = deriveChapters(paras);
      expect(chapters.map((c) => c.title).toList(), ['第一章 风起', '第二节', '第3卷']);
      expect(chapters.first.para, 2);
      // 超长行不误判
      expect(deriveChapters(['第一章 这是一个非常长的段落'.padRight(50, 'x')]), isEmpty);
    });
  });

  group('htmlToText', () {
    test('去标签/脚本/样式，解码实体，保留换行', () {
      const html =
          '<h1>标题</h1><p>甲&amp;乙<script>var x=1;</script><style>p{}</style></p>'
          '<p>第二段<br/>换行</p>';
      final text = htmlToText(html);
      expect(text, contains('标题'));
      expect(text, contains('甲&乙'));
      expect(text, contains('第二段\n换行'));
      expect(text, isNot(contains('script')));
      expect(text, isNot(contains('var x')));
    });

    test('数字实体解码', () {
      expect(htmlToText('<p>&#36825;&#x91CC;</p>'), '这里');
    });
  });

  group('importEpub', () {
    test('解析最小 epub：元数据与正文', () async {
      final novel = await importEpub(buildMinimalEpub());
      expect(novel.title, '测试邪神');
      expect(novel.author, '无敌贱客');
      // 目录标题与正文 h1 相同 → 只出现一次（不重复插标题）
      expect(novel.text.split('第一章 觉醒').length - 1, 1);
      expect(novel.text, contains('云澈&萧泠汐'));
      expect(novel.text, isNot(contains('var x')));
      // 无封面图
      expect(novel.coverJpg, isNull);
    });

    test('非 epub 字节抛 FormatException', () async {
      expect(
        () => importEpub(Uint8List.fromList('not an epub'.codeUnits)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

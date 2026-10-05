import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/source/source_assembly.dart';
import 'package:mandu_reader/features/source/source_cleaner.dart';
import 'package:mandu_reader/features/source/source_loader.dart';
import 'package:mandu_reader/features/source/source_models.dart';
import 'package:mandu_reader/features/source/source_ops.dart';
import 'package:mandu_reader/features/source/source_selector.dart';

void main() {
  group('书源资产（sources.json 全量回归）', () {
    final content = File('assets/rules/sources.json').readAsStringSync();
    final rules = parseRulesJson(content);
    final ops = buildDefaultOps();

    test('25 个源全部解析成功、slug 唯一', () {
      expect(rules.length, 25);
      final ids = rules.map((r) => r.sourceId).toSet();
      expect(ids.length, 25);
    });

    test('全量校验通过（结构 + 链语法 + 选择器可编译）', () {
      final failures = <String>[];
      for (final r in rules) {
        final errs = validateRule(r, ops);
        if (errs.isNotEmpty) failures.add('${r.sourceId}: ${errs.join(' / ')}');
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('CF 三源默认禁用并带原因', () {
      final disabled = {
        for (final r in rules)
          if (r.disabled) r.sourceId: r.disableReason,
      };
      expect(disabled.keys, containsAll(['xhytd', '96dushu', 'dongtanxs']));
      expect(disabled.values.every((v) => v.isNotEmpty), isTrue);
    });

    test('合并覆盖层：状态覆盖与整体替换', () {
      final merged = mergeOverrides(rules, [
        const SourceOverride(sourceId: 'xbiqugu', enabled: false),
        SourceOverride(
          sourceId: 'custom_x',
          json: jsonEncode({
            'sourceId': 'custom_x',
            'name': '自定义源',
            'url': 'https://example.com/',
            'book': {'bookName': 'h1', 'author': '.author'},
            'toc': {'item': '.list a'},
            'chapter': {'content': '#content'},
          }),
        ),
      ]);
      final xb = merged.firstWhere((r) => r.sourceId == 'xbiqugu');
      expect(xb.disabled, isTrue);
      final custom = merged.firstWhere((r) => r.sourceId == 'custom_x');
      expect(custom.search, isNull);
      expect(custom.book.bookNameSel, 'h1');
    });
  });

  group('选择器引擎', () {
    final engine = SelectorEngine();
    final doc = parseHtml('''
      <html><head><meta property="og:image" content="/cover.jpg"></head><body>
      <div id="list"><dl><dd><a href="/1.html">第一章</a></dd><dd><a href="/2.html">第二章</a></dd></dl></div>
      <p class="a">甲</p><p class="a">乙</p>
      </body></html>
    ''');

    test('CSS 选择 + 多元素 text 空格连接', () {
      expect(engine.select(doc, '#list dl dd a').length, 2);
      expect(engine.extract(doc, 'p.a'), '甲 乙');
    });

    test('@href 绝对链接归一（meta[ 前缀取 content）', () {
      expect(
        engine.extract(doc, '#list dd a@href', baseUrl: 'https://x.com/'),
        'https://x.com/1.html',
      );
      expect(
        engine.extract(
          doc,
          'meta[property="og:image"]',
          baseUrl: 'https://x.com/',
        ),
        '/cover.jpg',
      );
    });

    test('XPath 子集：/html、//div[@class][1]、//*[@id]', () {
      final d = parseHtml(
        '<html><body><div class="des bb">一</div><div class="des bb">二</div><div id="readbg"><script>var a=1;</script><script>nextpage = "/3.html";</script></div></body></html>',
      );
      expect(engine.select(d, '/html').length, 1);
      expect(engine.select(d, "//div[@class='des bb'][1]").single.text, '一');
      expect(
        engine.select(d, '//*[@id="readbg"]/script[2]').single.text,
        contains('nextpage'),
      );
    });

    test('回归：位置谓词 per-parent（//div[@class=x][1] = 每个父下第一个 div 孩子）', () {
      final d = parseHtml(
        '<html><body>'
        '<div class="x">A1<div class="x">B1</div><div class="x">B2</div></div>'
        '<div class="x">C1</div>'
        '</body></html>',
      );
      final hits = engine.select(d, "//div[@class='x'][1]");
      // 真 XPath 语义：A1（body 的第一个 div 孩子）、B1（A1 的第一个）；
      // C1 是 body 的第二个 div 孩子 → 不命中（这正是修复前的错误行为）
      expect(hits.map((e) => e.text.trim()).toList(), ['A1B1B2', 'B1']);
    });

    test('回归：复合谓词 [not(..) and not(..)] 逐条件生效而非整段丢弃', () {
      final d = parseHtml(
        '<html><body>'
        "<a href='/1'>首页</a><a href='/2'>上一页</a>"
        "<a href='/3'>正文</a><a href='/4'>尾页</a>"
        '</body></html>',
      );
      final hits = engine.select(
        d,
        "//a[not(text()='首页') and not(text()='上一页') and not(text()='尾页')]",
      );
      expect(hits.map((e) => e.text.trim()).toList(), ['正文']);
    });

    test('链式算子：regexExtract 作用于 XPath 选中内容', () {
      final d = parseHtml(
        '<html><body><div id="readbg"><script>var a=0;</script><script>var b=0;</script><script>var c=0;</script><script>nextpage = "/3.html";</script></div></body></html>',
      );
      final v = engine.extract(
        d,
        '//*[@id="readbg"]/script[4]@op:regexExtract(/nextpage = "(.*?)"/,1)',
        baseUrl: 'https://x.com',
      );
      expect(v, '/3.html');
    });
  });

  group('@op 算子', () {
    final ops = buildDefaultOps();
    const ctx = OpContext(sourceId: 't', baseUrl: 'https://x.com/a/');

    String run(String name, String input, List<Object?> args) =>
        ops.run(name, input, args, ctx);

    test('replace 首个 / replaceAll 全部', () {
      expect(run('replace', 'aa', ['a', 'b']), 'ba');
      expect(run('replaceAll', 'aa', ['a', 'b']), 'bb');
    });

    test('regexReplace：\$组引用与 g 标志', () {
      final re = parseArgs('/(\\d+)-(\\d+)/g').single as Object;
      expect(run('regexReplace', '第1-2章', [re, r'第$1.$2']), '第第1.2章');
      final re1 = parseArgs('/(\\d+)/').single;
      expect(run('regexReplace', 'a1b2', [re1, 'X']), 'aXb2');
    });

    test('prefix/absUrl/jsonpField', () {
      expect(run('prefix', '/x.jpg', ['https://cdn']), 'https://cdn/x.jpg');
      expect(run('absUrl', '../b.html', const []), 'https://x.com/b.html');
      final r = run('jsonpField', 'search({"content":"<p>hi</p>"})', [
        'content',
      ]);
      expect(r, '<p>hi</p>');
    });

    test('qsbsExtract/base64Lines 与 qsbsDecode', () {
      final b64 = base64.encode(utf8.encode('秘密正文'));
      // 真实页面 script 独占一行（so-novel base64.decode 按行解码的前提）
      final html =
          "<p>前</p>\n<script>document.writeln(qsbs.bb('$b64'));</script>\n<p>后</p>";
      expect(run('qsbsDecode', html, const []), '<p>前</p>\n秘密正文\n<p>后</p>');
      final extracted = run('qsbsExtract', html, const []);
      // so-novel 同款：行解码后直接拼接，无换行
      expect(run('base64Lines', extracted, const []), '<p>前</p>秘密正文<p>后</p>');
    });

    test('ddSortByDataId 按 id 排序拼接 p', () {
      const html = '<dd data-id="2"><p>二</p></dd><dd data-id="1"><p>一</p></dd>';
      expect(run('ddSortByDataId', html, const []), '<p>一</p><p>二</p>');
    });

    test('filterHiddenLis 裁掉首尾隐藏 li', () {
      const style =
          '.section-list.ycxsid>li:nth-child(1){display:none}.section-list.ycxsid>li:nth-last-child(1){display:none}';
      const ul =
          '<ul class="a section-list b ycxsid c"><li>1</li><li>2</li><li>3</li></ul>';
      final out = run('filterHiddenLis', '$style$ul', const []);
      expect(out, contains('<li>2</li>'));
      expect(out, isNot(contains('<li>1</li>')));
      expect(out, isNot(contains('<li>3</li>')));
    });

    test('quanbenSearchUrl 输出完整签名 URL', () {
      final url = run('quanbenSearchUrl', '斗破苍穹', const []);
      expect(url, startsWith('https://quanben5.com/?c=book&a=search.json'));
      expect(url, contains('keywords=斗破苍穹'));
      expect(url, contains('&b='));
    });

    test('回归：多算子链的每一段都执行（第二段起不再抛「未知步骤 @op」）', () {
      final engine = SelectorEngine();
      final out = engine.runChainOn(
        "x@op:replaceAll('a','b')@op:prefix('P')",
        'aa',
      );
      expect(out, 'Pbb');
      expect(
        SelectorEngine.chainOpNames("x@op:replaceAll('a','b')@op:prefix('P')"),
        ['replaceAll', 'prefix'],
      );
    });

    test('回归：纯算子链（@ 在位置 0，无选择器段）会真正执行', () {
      // 全本搜索 URL 即纯 @op: 链——@ 位置 0 时 stripChain 为空、链照常执行
      final engine = SelectorEngine();
      final out = engine.runChainOn('@op:quanbenSearchUrl()', '斗破苍穹');
      expect(out, startsWith('https://quanben5.com/'));
      // 纯链无选择器段：select 不抛错、命中为空
      final doc = parseHtml('<html><body></body></html>');
      expect(engine.select(doc, '@op:quanbenSearchUrl()'), isEmpty);
    });
  });

  group('清洗管线', () {
    ChapterRule rule({
      bool closed = false,
      String filterTxt = '',
      String filterTag = '',
    }) => ChapterRule.fromJson({
      'content': '#c',
      if (closed) 'paragraphTagClosed': true,
      if (filterTxt.isNotEmpty) 'filterTxt': filterTxt,
      if (filterTag.isNotEmpty) 'filterTag': filterTag,
    });

    test('隐形字符/实体/广告行/重复标题', () {
      final r = rule(filterTxt: '广告词|本章完');
      final raw = '<p>广告词</p><p>第一章</p>​<p>正文&hellip;内容</p><p>本章完</p>';
      final out = cleanChapter(r, '第一章', raw);
      expect(out.title, '第一章');
      // 与 toc 标题重复的首段被吞（章标题由 assembly 统一插入）
      expect(out.paragraphs, ['正文内容']);
    });

    test('filterTag 整段移除', () {
      final r = rule(filterTag: 'div, script');
      final out = cleanChapter(
        r,
        't',
        '<p>好</p><div>坏</div><script>x</script>',
      );
      expect(out.paragraphs, ['好']);
    });

    test('标题「1.章名」归一为「第1章 章名」', () {
      final out = cleanChapter(rule(), '1.风起', '<p>风起</p><p>正文</p>');
      expect(out.title, '第1章 风起');
    });

    test('<br>+ 分隔段落', () {
      final r = rule();
      final out = cleanChapter(r, 't', '甲<br><br>乙<br/>丙');
      expect(out.paragraphs, ['甲', '乙', '丙']);
    });

    test('回归：坏 paragraphTag 正则回退默认 <br> 切分，不整书报废', () {
      final r = rule();
      // 反射式注入坏 paragraphTag：直接调 _splitBySeparator 的公开入口 cleanChapter
      final bad = ChapterRule.fromJson(const {
        'content': '#c',
        'paragraphTag': '([',
      });
      final out = cleanChapter(bad, 't', '甲<br>乙');
      expect(out.paragraphs, ['甲', '乙']);
      expect(cleanChapter(r, 't', '甲<br>乙').paragraphs, ['甲', '乙']);
    });

    test('闭合标签段落：优先 p，无 p 用内层 div', () {
      expect(
        cleanChapter(rule(closed: true), 't', '<p>a</p><p>b</p>').paragraphs,
        ['a', 'b'],
      );
      expect(
        cleanChapter(
          rule(closed: true),
          't',
          '<div><div>x</div><div>y</div></div>',
        ).paragraphs,
        ['x', 'y'],
      );
    });
  });

  group('拼合 assembly', () {
    test('para/offset/标题去重/meta source 块', () {
      final book = assembleBook(
        workId: 'src_t_1',
        chapters: const [
          ChapterDraft('第一章', ['第一章', '甲', '乙']),
          ChapterDraft('第二章', ['丙']),
        ],
        bookName: '测试书',
        author: '作者',
        status: 'completed',
        sourceId: 't',
        bookUrl: 'https://x.com/book/1',
        today: '2026-10-04',
      );
      final chapters = (jsonDecode(book.chaptersJson) as List).cast<Map>();
      expect(chapters[0]['para'], 0);
      expect(chapters[1]['para'], 3); // 首章标题与首段重复未重复插入
      // 首章标题与首段重复未重复插入；次章标题正常插入 → 5 行
      expect(book.bookTxt.split('\n').where((l) => l.isNotEmpty).length, 5);
      expect(book.totalChars, '第一章甲乙第二章丙'.length);
      final meta = jsonDecode(book.metaJson) as Map;
      expect(meta['source'], containsPair('source_id', 't'));
      expect(meta['source'], containsPair('last_synced_chapter', 2));
      final vol = (meta['volumes'] as List).single as Map;
      final ch0 = (vol['chapters'] as List).first as Map;
      expect(ch0['offset'], 0);
      expect(ch0['chars'], '第一章甲乙'.length);
    });
  });
}

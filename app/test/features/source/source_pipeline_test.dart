import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/source/source_http.dart';
import 'package:mandu_reader/features/source/source_models.dart';
import 'package:mandu_reader/features/source/source_pipeline.dart';

/// 假 HTTP：路由表 url→响应；failFirstTimes 模拟前 N 次失败（重试验证）。
class _FakeHttp implements SourceHttp {
  final Map<String, String> routes;
  Map<String, int> failFirstTimes;
  final Map<String, int> hits = {};

  _FakeHttp({required this.routes, this.failFirstTimes = const {}});

  @override
  Future<String> get(String url, {int timeoutSec = 15, String? cookie}) =>
      _respond(url);

  @override
  Future<String> post(
    String url,
    Map<String, String> form, {
    int timeoutSec = 15,
    String? cookie,
  }) => _respond(url);

  Future<String> _respond(String url) async {
    final n = (hits[url] ?? 0) + 1;
    hits[url] = n;
    final failTimes = failFirstTimes[url] ?? 0;
    if (n <= failTimes) throw StateError('HTTP 500（模拟）');
    final r = routes[url];
    if (r == null) throw StateError('404: $url');
    return r;
  }

  @override
  Future<List<int>> getBytes(
    String url, {
    int timeoutSec = 30,
    String? cookie,
  }) => Future.error(StateError('no bytes'));
}

SourceRule _rule() => SourceRule.fromJson('fake', {
  'sourceId': 'fake',
  'name': '假源',
  'url': 'https://fake.test/',
  'book': {'bookName': 'h1', 'author': '.author'},
  'toc': {'item': '.list a'},
  'chapter': {'content': '#txt'},
});

void main() {
  group('下载管线 e2e（FakeSourceHttp）', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('mandu_pipeline');
    });
    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    NovelSnapshot snap() => NovelSnapshot(
      sourceId: 'fake',
      bookUrl: 'https://fake.test/book/1',
      bookName: '测试书',
      author: '作者甲',
      status: '连载中',
      chapters: const [
        SourceChapter(title: '第一章', url: 'https://fake.test/1.html', order: 1),
        SourceChapter(title: '第二章', url: 'https://fake.test/2.html', order: 2),
        SourceChapter(title: '第三章', url: 'https://fake.test/3.html', order: 3),
      ],
    );

    const ch1 = '<div id="txt">第一章<br>甲段落<br><br>乙段落</div>';
    const ch2 = '<div id="txt">第二章<br>丙段落</div>';
    const ch3 = '<div id="txt">第三章<br>丁段落</div><script>ad</script>';

    test('一章重试后成功、一章彻底失败 → 缺章清单；续跑幂等补齐', () async {
      final http = _FakeHttp(
        routes: {
          'https://fake.test/1.html': ch1,
          'https://fake.test/2.html': ch2,
          'https://fake.test/3.html': ch3,
        },
        failFirstTimes: {
          'https://fake.test/1.html': 2, // 前 2 次挂，第 3 次成功
          'https://fake.test/2.html': 99, // 永远失败
        },
      );
      final pipeline = SourcePipeline(rule: _rule(), http: http);

      // 第一轮：ch1 重试成功、ch2 死透 → 缺章 [2]
      await expectLater(
        pipeline.download(
          root: root.path,
          snap: snap(),
          concurrency: 2,
          attempts: 3,
          onProgress: (_) {},
        ),
        throwsA(
          isA<NovelDownloadIncomplete>().having(
            (e) => e.failedChapters,
            'failedChapters',
            [2],
          ),
        ),
      );
      // staging 保留：ch1 已落盘（重试后成功），ch3 成功，ch2 无文件
      final tmp = Directory('${root.path}/_novel_tmp/${snap().workId}');
      expect(File('${tmp.path}/0.txt').existsSync(), isTrue);
      expect(File('${tmp.path}/1.txt').existsSync(), isFalse);
      expect(File('${tmp.path}/2.txt').existsSync(), isTrue);

      // 第二轮：修好 ch2 → 幂等续跑（ch1/ch3 不重复抓取）
      http.failFirstTimes = const {};
      http.hits.clear();
      final result = await pipeline.download(
        root: root.path,
        snap: snap(),
        concurrency: 2,
        attempts: 3,
        onProgress: (_) {},
      );
      expect(result.complete, isTrue);
      expect(http.hits['https://fake.test/1.html'] ?? 0, 0); // tmp 命中未重抓
      expect(http.hits['https://fake.test/3.html'] ?? 0, 0);
      expect(http.hits['https://fake.test/2.html'], 1);

      // 产物齐全
      final dir = Directory('${root.path}/${snap().workId}');
      final bookTxt = File('${dir.path}/book.txt').readAsStringSync();
      expect(bookTxt.split('\n').where((l) => l.isNotEmpty).toList(), [
        '第一章',
        '甲段落',
        '乙段落',
        '第二章',
        '丙段落',
        '第三章',
        '丁段落',
      ]);
      final chapters = (jsonDecode(
        File('${dir.path}/chapters.json').readAsStringSync(),
      ) as List).cast<Map>();
      expect(chapters[1]['para'], 3);
      final meta =
          jsonDecode(File('${dir.path}/meta.json').readAsStringSync()) as Map;
      expect(
        meta['source'],
        containsPair('book_url', 'https://fake.test/book/1'),
      );
      expect(meta['status'], 'ongoing');
      expect(meta['total_chars'], '第一章甲段落乙段落第二章丙段落第三章丁段落'.length);
      // staging 已清理
      expect(tmp.existsSync(), isFalse);
    });

    test('workId 由 sourceId+bookUrl 派生且恒定', () {
      expect(
        novelWorkId('fake', 'https://a/1'),
        novelWorkId('fake', 'https://a/1'),
      );
      expect(novelWorkId('fake', 'https://a/1'), startsWith('src_fake_'));
      expect(
        novelWorkId('fake', 'https://a/2'),
        isNot(novelWorkId('fake', 'https://a/1')),
      );
    });
  });
}

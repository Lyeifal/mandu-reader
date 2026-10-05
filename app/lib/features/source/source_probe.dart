/// 单源四步巡检核心（纯引擎层：规则 + 已建好的 http，零 Flutter）。
/// App 内单源测试与 tool/source_doctor.dart 共用。
library;

import 'source_book.dart';
import 'source_chapter.dart';
import 'source_http.dart';
import 'source_models.dart';
import 'source_search.dart';
import 'source_selector.dart';
import 'source_toc.dart';

/// 内置探针书：常见书名（各站基本都有）；--probe 可覆盖。
const sourceProbes = <String, ({String keyword, String bookUrl})>{
  'default': (keyword: '斗破苍穹', bookUrl: ''),
};

/// 返回 `ok` 或 `fail@<step>: <原因>`；CF 挑战返回 `cf_challenge: …`。
Future<String> probeSource(
  SourceRule rule,
  SourceHttp http, {
  String? probeKeyword,
  String? probeBookUrl,
}) async {
  final probe = sourceProbes[rule.sourceId] ?? sourceProbes['default']!;
  final keyword = probeKeyword ?? probe.keyword;
  final engine = SelectorEngine();

  try {
    // 1) 搜索（不支持搜索的源跳过，不算失败）
    String bookUrl = probeBookUrl ?? probe.bookUrl;
    if (rule.searchable) {
      final results = await SourceSearch(
        rule,
        http,
        engine,
      ).search(keyword, limit: 1).timeout(const Duration(seconds: 40));
      if (results.isEmpty) return 'fail@search: 无结果';
      bookUrl = results.first.bookUrl;
    }
    if (bookUrl.isEmpty) return 'skip: 无搜索能力（需 bookUrl 探针，未实测）';

    // 2) 详情
    await SourceBook(
      rule,
      http,
      engine,
    ).parse(bookUrl).timeout(const Duration(seconds: 40));

    // 3) 目录
    final toc = await SourceToc(
      rule,
      http,
      engine,
    ).parseAll(bookUrl).timeout(const Duration(seconds: 60));
    if (toc.isEmpty) return 'fail@toc: 目录为空';

    // 4) 正文（取中段一章，避开可能的收费/空章）
    final pick = toc[toc.length ~/ 2];
    final raw = await SourceChapterFetcher(
      rule,
      http,
      engine,
    ).fetch(pick.url).timeout(const Duration(seconds: 40));
    if (raw.trim().length < 50) return 'fail@chapter: 正文过短（选择器可能失效）';
    if (looksLikeCf(raw)) return 'cf_challenge: ${pick.url}';
    return 'ok';
  } on CfChallengeException catch (e) {
    return 'cf_challenge: $e';
  } on Object catch (e) {
    return 'fail: ${e.toString().split('\n').first}';
  }
}

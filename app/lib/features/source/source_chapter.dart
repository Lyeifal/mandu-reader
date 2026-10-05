/// 章节正文抓取（单源，零 Flutter 依赖）。语义对照 so-novel ChapterParser：
/// - 无 nextPage → 单页；有 nextPage → 循环拼接分页正文
/// - 末页判定：nextChapterLink 正则命中 ||（URL 不像 `_N.html` 且按钮文案含 下一章/没有了/>>/书末页）
/// - 回环保护：visited 集合 + 50 页硬上限
/// 重试由调用方（pipeline withRetry）负责，本类单次尝试。
library;

import 'package:html/dom.dart' as dom;

import 'source_http.dart';
import 'source_ops.dart';
import 'source_search.dart';
import 'source_models.dart';
import 'source_selector.dart';

/// 单章抓取器。
class SourceChapterFetcher {
  SourceChapterFetcher(this.rule, this.http, this.engine);

  final SourceRule rule;
  final SourceHttp http;
  final SelectorEngine engine;

  /// 返回正文原始 HTML（未清洗；清洗在 source_cleaner）。
  Future<String> fetch(String chapterUrl) async {
    final r = rule.chapter;
    final base = r.baseUri.isNotEmpty ? r.baseUri : rule.siteUrl;
    if (r.nextPage.trim().isEmpty) {
      final body = await http.get(chapterUrl, timeoutSec: r.timeoutSec);
      if (looksLikeCf(body)) throw CfChallengeException(chapterUrl);
      final doc = parseHtml(body);
      final content = engine.extract(
        doc,
        r.content,
        kind: ExtractKind.html,
        baseUrl: base,
        sourceId: rule.sourceId,
      );
      if (content.trim().isEmpty) {
        throw StateError('正文内容为空（选择器失效或正文延迟加载）');
      }
      return content;
    }
    return _fetchPaginated(chapterUrl, base);
  }

  Future<String> _fetchPaginated(String startUrl, String base) async {
    final r = rule.chapter;
    final buf = StringBuffer();
    var nextUrl = startUrl;
    final visited = <String>{startUrl};

    for (var page = 0; page < 50; page++) {
      final body = await http.get(nextUrl, timeoutSec: r.timeoutSec);
      if (looksLikeCf(body)) throw CfChallengeException(nextUrl);
      final doc = parseHtml(body);

      final content = engine.extract(
        doc,
        r.content,
        kind: ExtractKind.html,
        baseUrl: base,
        sourceId: rule.sourceId,
      );
      if (content.trim().isEmpty) {
        throw StateError('分页正文为空（第 ${page + 1} 页，可能被限流）');
      }
      buf.write(content);

      final candidate = await _resolveNextUrl(doc, base);
      if (_isLastPage(candidate, doc)) break;
      nextUrl = candidate!;
      if (!visited.add(nextUrl)) break; // 回环
    }
    return buf.toString();
  }

  Future<String?> _resolveNextUrl(dom.Document doc, String base) async {
    final r = rule.chapter;
    if (r.nextPageInJs.trim().isNotEmpty) {
      final v = engine.extract(
        doc,
        r.nextPageInJs,
        kind: ExtractKind.html,
        baseUrl: base,
        sourceId: rule.sourceId,
      );
      return v.trim().isEmpty ? null : v.trim();
    }
    final els = engine.select(doc, r.nextPage);
    if (els.isEmpty) return null;
    return absUrl(els.first.attributes['href'] ?? '', base);
  }

  bool _isLastPage(String? nextUrl, dom.Document doc) {
    if (nextUrl == null || nextUrl.isEmpty) return true;
    final r = rule.chapter;
    if (r.nextChapterLink.trim().isNotEmpty &&
        RegExp(r.nextChapterLink).hasMatch(nextUrl)) {
      return true;
    }
    // 通用规则：URL 以「-_N.html」结尾是分页；否则按钮文案说「下一章/没有了」即末页
    final looksPage = RegExp(r'.*[-_]\d\.html').hasMatch(nextUrl);
    if (looksPage) return false;
    final els = engine.select(doc, r.nextPage);
    final btnText = els.map((e) => e.text).join(' ');
    return RegExp('下一章|没有了|>>|书末页').hasMatch(btnText);
  }
}

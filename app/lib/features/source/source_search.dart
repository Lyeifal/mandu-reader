/// 搜索解析（单源，零 Flutter 依赖）。
///
/// 语义对照 so-novel SearchParser：
/// - search.url 含 `@op:` 链 → 输入 keyword 输出完整 URL（签名类）；
///   否则 `%s` 替换 keyword
/// - POST data 为 `{k:v}` 宽松 JSON，v=`%s` 按序吃 keyword
/// - 结果为空但命中 book.bookName → 视为精确匹配跳详情页，构造单条结果
library;

import 'package:html/dom.dart' as dom;

import 'source_book.dart';
import 'source_http.dart';
import 'source_models.dart';
import 'source_ops.dart';
import 'source_selector.dart';

/// CF 挑战页异常：pipeline/单源测试捕获后禁用该源。
class CfChallengeException implements Exception {
  CfChallengeException(this.url);

  final String url;

  @override
  String toString() => 'Cloudflare 挑战页: $url';
}

class SourceSearch {
  SourceSearch(this.rule, this.http, this.engine);

  final SourceRule rule;
  final SourceHttp http;
  final SelectorEngine engine;

  Future<List<SourceSearchResult>> search(
    String keyword, {
    int limit = 20,
  }) async {
    final r = rule.search;
    if (r == null || r.disabled) return const [];
    final searchUrl = _buildSearchUrl(r, keyword);
    final body = await _fetch(r, searchUrl, keyword);
    final base = r.baseUri.isNotEmpty ? r.baseUri : rule.siteUrl;
    final doc = parseHtml(
      engine.runChainOn(r.result, body, baseUrl: base, sourceId: rule.sourceId),
    );
    if (looksLikeCf(body)) throw CfChallengeException(searchUrl);

    final results = _extractResults(doc, r, base, limit);

    // 精确匹配跳详情页：合成单条结果
    if (results.isEmpty &&
        r.result.isNotEmpty &&
        engine.select(doc, rule.book.bookNameSel).isNotEmpty) {
      try {
        final info = await SourceBook(rule, http, engine).parse(searchUrl);
        if (info.bookName.isNotEmpty) {
          return [
            SourceSearchResult(
              sourceId: rule.sourceId,
              sourceName: rule.name,
              bookUrl: info.url,
              bookName: info.bookName,
              author: info.author,
              category: info.category,
              latestChapter: info.latestChapter,
              lastUpdateTime: info.lastUpdateTime,
              status: info.status,
            ),
          ];
        }
      } on Object {
        // 合成失败按无结果处理
      }
      return const [];
    }

    // 搜索结果无分页
    if (r.nextPage.trim().isEmpty) return results;

    // 有分页：一次性收集分页 URL（option 下拉或翻页按钮）
    final nextEls = engine.select(doc, r.nextPage);
    if (nextEls.isEmpty) return results;
    final pageUrls = <String>{};
    for (final el in nextEls) {
      final href = el.attributes['href'] ?? el.attributes['value'] ?? '';
      final abs = absUrl(href, base);
      if (abs.startsWith('http')) pageUrls.add(abs);
    }
    final all = [...results];
    for (final pageUrl in pageUrls) {
      if (all.length >= limit) break;
      try {
        final pageBody = await http.get(
          pageUrl,
          timeoutSec: r.timeoutSec,
          cookie: r.cookies,
        );
        if (looksLikeCf(pageBody)) continue;
        final pageDoc = parseHtml(
          engine.runChainOn(
            r.result,
            pageBody,
            baseUrl: base,
            sourceId: rule.sourceId,
          ),
        );
        all.addAll(_extractResults(pageDoc, r, base, limit - all.length));
      } on Object {
        // 分页失败不拖垮首页结果
      }
    }
    return all.length > limit ? all.sublist(0, limit) : all;
  }

  String _buildSearchUrl(SearchRule r, String keyword) {
    if (r.url.contains('@op:')) {
      return engine
          .runChainOn(
            r.url,
            keyword,
            baseUrl: rule.siteUrl,
            sourceId: rule.sourceId,
          )
          .trim();
    }
    // 关键词百分号编码：裸空格会让 Uri.parse 直接抛错（多词英文书名必踩）
    return r.url.replaceAll('%s', Uri.encodeQueryComponent(keyword));
  }

  Future<String> _fetch(SearchRule r, String url, String keyword) {
    if (r.method.toUpperCase() == 'POST') {
      return http.post(
        url,
        _buildForm(r.data, keyword),
        timeoutSec: r.timeoutSec,
        cookie: r.cookies,
      );
    }
    return http.get(url, timeoutSec: r.timeoutSec, cookie: r.cookies);
  }

  /// `{k1: v1, k2: %s}` 宽松解析（键可不带引号，容忍尾逗号）。
  static Map<String, String> _buildForm(String template, String keyword) {
    final out = <String, String>{};
    var t = template.trim();
    if (t.startsWith('{')) t = t.substring(1);
    if (t.endsWith('}')) t = t.substring(0, t.length - 1);
    var usedKeyword = false;
    for (final pair in t.split(',')) {
      final idx = pair.indexOf(':');
      if (idx < 0) continue;
      final k = pair
          .substring(0, idx)
          .trim()
          .replaceAll(RegExp('^["\\\']|["\\\']\$'), '');
      var v = pair
          .substring(idx + 1)
          .trim()
          .replaceAll(RegExp('^["\\\']|["\\\']\$'), '');
      if (v == '%s' && !usedKeyword) {
        v = keyword;
        usedKeyword = true;
      }
      if (k.isNotEmpty) out[k] = v;
    }
    return out;
  }

  List<SourceSearchResult> _extractResults(
    dom.Document doc,
    SearchRule r,
    String base,
    int limit,
  ) {
    final out = <SourceSearchResult>[];
    final resultEls = engine.select(doc, r.result);
    if (resultEls.isEmpty) {
      // 精确匹配跳详情页：页面本身就是详情，构造单条结果（书名非空才算）
      if (engine.select(doc, rule.book.bookNameSel).isEmpty) return out;
      return out; // 由 search() 走详情合成
    }
    for (final el in resultEls) {
      if (out.length >= limit) break;
      final bookName = engine.extract(
        el,
        r.bookNameSel,
        baseUrl: base,
        sourceId: rule.sourceId,
      );
      if (bookName.isEmpty) continue;
      final url = engine.extract(
        el,
        r.bookNameSel,
        kind: ExtractKind.attrHref,
        baseUrl: base,
        sourceId: rule.sourceId,
      );
      out.add(
        SourceSearchResult(
          sourceId: rule.sourceId,
          sourceName: rule.name,
          bookUrl: url,
          bookName: bookName,
          author: engine.extract(
            el,
            r.author,
            baseUrl: base,
            sourceId: rule.sourceId,
          ),
          category: engine.extract(
            el,
            r.category,
            baseUrl: base,
            sourceId: rule.sourceId,
          ),
          latestChapter: engine.extract(
            el,
            r.latestChapter,
            baseUrl: base,
            sourceId: rule.sourceId,
          ),
          lastUpdateTime: engine.extract(
            el,
            r.lastUpdateTime,
            baseUrl: base,
            sourceId: rule.sourceId,
          ),
          status: engine.extract(
            el,
            r.status,
            baseUrl: base,
            sourceId: rule.sourceId,
          ),
          wordCount: engine.extract(
            el,
            r.wordCount,
            baseUrl: base,
            sourceId: rule.sourceId,
          ),
        ),
      );
    }
    return out;
  }
}

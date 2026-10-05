/// 目录解析（单源，零 Flutter 依赖）。语义对照 so-novel TocParser：
/// - book.url 是书号提取正则（group1），目录 URL/baseUri 模板用 `%s` 拼书号
/// - 分页：option 下拉（元素有 value 属性 → 收集全部 option URL）或递归「下一页」
/// - toc.list：先提取一块 HTML 再在内部选 item（ul 结构）
/// - isDesc：页内倒序；多页按 URL 收集顺序拼接
library;

import 'package:html/dom.dart' as dom;

import 'source_http.dart';
import 'source_models.dart';
import 'source_ops.dart';
import 'source_search.dart';
import 'source_selector.dart';

class SourceToc {
  SourceToc(this.rule, this.http, this.engine);

  final SourceRule rule;
  final SourceHttp http;
  final SelectorEngine engine;

  /// [bookPageUrl] 详情页 URL；返回正序（阅读顺序）章节列表。
  Future<List<SourceChapter>> parseAll(String bookPageUrl) async {
    final r = rule.toc;

    // 书号：book.url 正则（去掉可能的链）对详情页 URL 取 group1
    String? id;
    final bookUrlPattern = SelectorEngine.stripChain(rule.book.url).trim();
    if (bookUrlPattern.isNotEmpty) {
      id = RegExp(bookUrlPattern).firstMatch(bookPageUrl)?.group(1);
    }

    // baseUri / tocUrl 模板拼书号
    final baseUri = (id != null && r.baseUri.contains('%s'))
        ? r.baseUri.replaceAll('%s', id)
        : (r.baseUri.isNotEmpty ? r.baseUri : rule.siteUrl);
    final tocUrl = r.url.isNotEmpty
        ? (id != null ? r.url.replaceAll('%s', id) : r.url)
        : bookPageUrl;

    final urls = <String>[tocUrl];
    if (r.nextPage.trim().isNotEmpty) {
      final first = await _fetch(tocUrl, baseUri);
      await _collectPaginationUrls(urls, first, r, baseUri, tocUrl);
    }

    // 逐页抓取提取（页数少，顺序即可；HTTP 层已做间隔节流）
    final out = <SourceChapter>[];
    var order = 1;
    for (final pageUrl in urls) {
      dom.Document doc;
      try {
        doc = await _fetch(pageUrl, baseUri);
      } on Object {
        continue; // 单页失败不拖垮整目录
      }
      final els = _extractItems(doc, r);
      final indexed = r.isDesc ? els.reversed.toList() : els;
      for (final el in indexed) {
        final title = el.text.trim();
        final href = el.attributes['href'] ?? '';
        final url = absUrl(href, baseUri);
        if (title.isEmpty || url.isEmpty) continue;
        // toc.nextPage 仅贡献 DSL 链（href 已在上面取过）
        final chained = engine.runChainOn(
          r.nextPage,
          url,
          baseUrl: baseUri,
          sourceId: rule.sourceId,
        );
        out.add(
          SourceChapter(
            title: title,
            url: chained.isEmpty ? url : chained,
            order: order++,
          ),
        );
      }
    }
    return out;
  }

  Future<dom.Document> _fetch(String url, String baseUri) async {
    final body = await http.get(url, timeoutSec: rule.toc.timeoutSec);
    if (looksLikeCf(body)) throw CfChallengeException(url);
    return parseHtml(body);
  }

  Future<void> _collectPaginationUrls(
    List<String> urls,
    dom.Document doc,
    TocRule r,
    String baseUri,
    String tocUrl,
  ) async {
    final els = engine.select(doc, r.nextPage);
    if (els.isEmpty) return;
    // option 下拉：有 value 属性 → 收集全部（href 优先，其次 value）
    final hasValue = els.any((e) => e.attributes.containsKey('value'));
    if (hasValue) {
      // so-novel 语义：urls.remove(s); urls.add(s)——option 顺序为准，
      // tocUrl 不在 option 里时保持首位
      final ordered = <String>[];
      for (final el in els) {
        final raw = (el.attributes['href']?.isNotEmpty == true)
            ? el.attributes['href']!
            : (el.attributes['value'] ?? '');
        final abs = absUrl(raw, baseUri);
        if (abs.startsWith('http')) {
          ordered.remove(abs);
          ordered.add(abs);
        }
      }
      urls
        ..clear()
        ..add(tocUrl)
        ..addAll(ordered.where((u) => u != tocUrl));
      return;
    }
    // 递归「下一页」按钮（带回环保护）
    var cur = doc;
    final visited = urls.toSet();
    for (var guard = 0; guard < 50; guard++) {
      final href = engine.extract(
        cur,
        r.nextPage,
        kind: ExtractKind.attrHref,
        baseUrl: baseUri,
        sourceId: rule.sourceId,
      );
      final next = href.isNotEmpty
          ? href
          : engine.extract(
              cur,
              r.nextPage,
              kind: ExtractKind.attrContent,
              baseUrl: baseUri,
              sourceId: rule.sourceId,
            );
      if (next.isEmpty || !next.startsWith('http') || visited.contains(next)) {
        break;
      }
      urls.add(next);
      visited.add(next);
      try {
        cur = await _fetch(next, baseUri);
      } on Object {
        break;
      }
    }
  }

  List<dom.Element> _extractItems(dom.Document doc, TocRule r) {
    if (r.list.trim().isNotEmpty) {
      final tocHtml = engine.extract(
        doc,
        r.list,
        kind: ExtractKind.html,
        baseUrl: r.baseUri,
        sourceId: rule.sourceId,
      );
      if (tocHtml.isEmpty) return const [];
      return engine.select(parseHtml(tocHtml), r.item);
    }
    return engine.select(doc, r.item);
  }
}

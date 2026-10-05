/// 详情页解析（单源，零 Flutter 依赖）。语义对照 so-novel BookParser。
library;

import 'source_http.dart';
import 'source_search.dart';
import 'source_models.dart';
import 'source_selector.dart';

class SourceBook {
  SourceBook(this.rule, this.http, this.engine);

  final SourceRule rule;
  final SourceHttp http;
  final SelectorEngine engine;

  /// [url] 详情页绝对地址；书名/作者为空视为解析失败（抛 StateError）。
  Future<SourceBookInfo> parse(String url) async {
    final r = rule.book;
    final body = await http.get(url, timeoutSec: r.timeoutSec);
    if (looksLikeCf(body)) throw CfChallengeException(url);
    final base = r.baseUri.isNotEmpty ? r.baseUri : url;
    final doc = parseHtml(body);

    String pick(String sel) => sel.trim().isEmpty
        ? ''
        : engine.extract(doc, sel, baseUrl: base, sourceId: rule.sourceId);

    final bookName = pick(r.bookNameSel);
    final author = pick(r.author).replaceAll('作者：', '');
    if (bookName.isEmpty || author.isEmpty) {
      throw StateError('详情页书名或作者为空（选择器失效或页面结构变了）');
    }
    return SourceBookInfo(
      url: url,
      bookName: bookName,
      author: author,
      intro: pick(r.intro),
      category: pick(r.category),
      coverUrl: pick(r.coverUrl),
      latestChapter: pick(r.latestChapter),
      latestChapterUrl: pick(r.latestChapterUrl),
      lastUpdateTime: pick(r.lastUpdateTime)
          .replaceAll(RegExp('(更新时间|最后更新)：'), ''),
      status: pick(r.status),
    );
  }
}

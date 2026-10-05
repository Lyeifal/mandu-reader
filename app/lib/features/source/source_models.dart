/// 书源规则模型（M5，设计文档 §8）。
///
/// 方言派生自 so-novel（AGPL-3.0，规则数据见 assets/rules/NOTICE.md），
/// 差异：原 `@js:`/`@java:` 链已改写为本引擎的 `@op:name(args)` 算子链
/// （见 source_ops.dart），语义保持一致：链上每步接收上一步的字符串输出。
library;

/// 书源规则（五段：search / book / toc / chapter / crawl）。
class SourceRule {
  SourceRule({
    required this.sourceId,
    required this.name,
    required this.siteUrl,
    required this.comment,
    required this.group,
    required this.language,
    required this.needProxy,
    required this.disabled,
    required this.disableReason,
    this.search,
    required this.book,
    required this.toc,
    required this.chapter,
    required this.crawl,
  });

  final String sourceId;
  final String siteUrl;
  final String name;
  final String comment;

  /// 来源分组：main / proxy-required / rate-limit / no-search / cloudflare / custom。
  final String group;

  /// 源站语言（zh-CN/zh-TW…）；M5 不做简繁转换，仅展示标注。
  final String language;

  final bool needProxy;
  final bool disabled;
  final String disableReason;

  final SearchRule? search;
  final BookRule book;
  final TocRule toc;
  final ChapterRule chapter;
  final CrawlRule crawl;

  bool get searchable => search != null && !(search!.disabled);

  factory SourceRule.fromJson(String sourceId, Map<String, dynamic> json) {
    Map<String, dynamic>? map(String k) => json[k] is Map<String, dynamic>
        ? json[k] as Map<String, dynamic>
        : null;
    return SourceRule(
      sourceId: sourceId,
      name: (json['name'] ?? '').toString(),
      siteUrl: (json['url'] ?? '').toString(),
      comment: (json['comment'] ?? '').toString(),
      group: (json['group'] ?? 'custom').toString(),
      language: (json['language'] ?? '').toString(),
      needProxy: json['needProxy'] == true,
      disabled: json['disabled'] == true,
      disableReason: (json['disableReason'] ?? '').toString(),
      search: map('search') == null
          ? null
          : SearchRule.fromJson(map('search')!, json['url']?.toString() ?? ''),
      book: BookRule.fromJson(map('book') ?? const {}),
      toc: TocRule.fromJson(
        map('toc') ?? const {},
        json['url']?.toString() ?? '',
      ),
      chapter: ChapterRule.fromJson(map('chapter') ?? const {}),
      crawl: CrawlRule.fromJson(map('crawl')),
    );
  }

  /// 导入校验：返回错误列表（空 = 合法）。比运行时更严格（必填段齐全）。
  List<String> validate() {
    final errs = <String>[];
    if (name.isEmpty) errs.add('缺少 name');
    if (siteUrl.isEmpty) errs.add('缺少 url（站点地址）');
    if (book.bookNameSel.isEmpty) errs.add('book.bookName 必填');
    if (toc.item.isEmpty) errs.add('toc.item 必填');
    if (chapter.content.isEmpty) errs.add('chapter.content 必填');
    if (search != null && search!.url.isEmpty) {
      errs.add('search.url 必填（不需要搜索可整段去掉 search）');
    }
    return errs;
  }
}

class SearchRule {
  SearchRule({
    required this.disabled,
    required this.baseUri,
    required this.timeoutSec,
    required this.url,
    required this.method,
    required this.data,
    required this.cookies,
    required this.result,
    required this.bookNameSel,
    required this.author,
    required this.category,
    required this.latestChapter,
    required this.lastUpdateTime,
    required this.status,
    required this.wordCount,
    required this.nextPage,
  });

  final bool disabled;
  final String baseUri;
  final int timeoutSec;

  /// 可含 `%s`（keyword 替换）或整串为 `@op:` 链（签名类插件）。
  final String url;
  final String method; // GET | POST，缺省 GET
  final String data; // `{k:v}` 模板，v 为 %s 时按序吃 keyword
  final String cookies;
  final String result;
  final String bookNameSel;
  final String author;
  final String category;
  final String latestChapter;
  final String lastUpdateTime;
  final String status;
  final String wordCount;
  final String nextPage;

  factory SearchRule.fromJson(Map<String, dynamic> j, String siteUrl) =>
      SearchRule(
        disabled: j['disabled'] == true,
        baseUri: (j['baseUri'] ?? siteUrl).toString(),
        timeoutSec: (j['timeout'] as num?)?.toInt() ?? 15,
        url: (j['url'] ?? '').toString(),
        method: ((j['method'] ?? 'GET').toString()).toUpperCase(),
        data: (j['data'] ?? '').toString(),
        cookies: (j['cookies'] ?? '').toString(),
        result: (j['result'] ?? '').toString(),
        bookNameSel: (j['bookName'] ?? '').toString(),
        author: (j['author'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        latestChapter: (j['latestChapter'] ?? '').toString(),
        lastUpdateTime: (j['lastUpdateTime'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        wordCount: (j['wordCount'] ?? '').toString(),
        nextPage: (j['nextPage'] ?? '').toString(),
      );
}

class BookRule {
  BookRule({
    required this.baseUri,
    required this.timeoutSec,
    required this.url,

    /// 书号提取正则（group1=书号）：目录页/搜索 URL 模板用它拼。
    required this.bookNameSel,
    required this.author,
    required this.intro,
    required this.category,
    required this.coverUrl,
    required this.latestChapter,
    required this.latestChapterUrl,
    required this.lastUpdateTime,
    required this.status,
  });

  final String baseUri;
  final int timeoutSec;

  /// 注意：so-novel 语义下这是「详情页 URL 书号正则」，不是选择器。
  final String url;
  final String bookNameSel;
  final String author;
  final String intro;
  final String category;
  final String coverUrl;
  final String latestChapter;
  final String latestChapterUrl;
  final String lastUpdateTime;
  final String status;

  factory BookRule.fromJson(Map<String, dynamic> j) {
    // so-novel applyDefaultRule：book 段留空的字段用 og meta 选择器兜底
    String d(String key, String metaSel) {
      final v = (j[key] ?? '').toString();
      return v.isEmpty ? metaSel : v;
    }

    return BookRule(
      baseUri: (j['baseUri'] ?? '').toString(),
      timeoutSec: (j['timeout'] as num?)?.toInt() ?? 15,
      url: (j['url'] ?? '').toString(),
      bookNameSel: d('bookName', 'meta[property="og:novel:book_name"]'),
      author: d('author', 'meta[property="og:novel:author"]'),
      intro: d('intro', 'meta[name="description"]'),
      category: d('category', 'meta[property="og:novel:category"]'),
      coverUrl: d('coverUrl', 'meta[property="og:image"]'),
      latestChapter: d(
        'latestChapter',
        'meta[property="og:novel:latest_chapter_name"]',
      ),
      latestChapterUrl: d(
        'latestChapterUrl',
        'meta[property="og:novel:latest_chapter_url"]',
      ),
      lastUpdateTime: d(
        'lastUpdateTime',
        'meta[property="og:novel:update_time"]',
      ),
      status: d('status', 'meta[property="og:novel:status"]'),
    );
  }
}

class TocRule {
  TocRule({
    required this.baseUri,
    required this.timeoutSec,

    /// 目录页 URL 模板（含 %s=书号）；空 = 详情页即目录页。
    required this.url,

    /// 可选：先提取一块 HTML 再在内部选 item（ul 结构）。
    required this.list,
    required this.item,
    required this.isDesc,
    required this.nextPage,
  });

  final String baseUri;
  final int timeoutSec;
  final String url;
  final String list;
  final String item;
  final bool isDesc;

  /// 分页：option 下拉（has value 属性则收集全部）或递归「下一页」按钮。
  final String nextPage;

  factory TocRule.fromJson(Map<String, dynamic> j, String siteUrl) => TocRule(
    baseUri: (j['baseUri'] ?? siteUrl).toString(),
    timeoutSec: (j['timeout'] as num?)?.toInt() ?? 60,
    url: (j['url'] ?? '').toString(),
    list: (j['list'] ?? '').toString(),
    item: (j['item'] ?? '').toString(),
    isDesc: j['isDesc'] == true,
    nextPage: (j['nextPage'] ?? '').toString(),
  );
}

class ChapterRule {
  ChapterRule({
    required this.baseUri,
    required this.timeoutSec,
    required this.title,
    required this.content,
    required this.paragraphTagClosed,
    required this.paragraphTag,
    required this.filterTxt,
    required this.filterTag,
    required this.nextPage,
    required this.nextPageInJs,
    required this.nextChapterLink,
  });

  final String baseUri;
  final int timeoutSec;
  final String title;
  final String content;
  final bool paragraphTagClosed;

  /// 未闭合段落分隔标记（如 `<br>+` = 一个或多个 <br>）。
  final String paragraphTag;

  /// 广告文本正则（`|` 连接的多个模式）。
  final String filterTxt;

  /// 要整段移除的标签选择器（逗号分隔，如 `div, p, script`）。
  final String filterTag;
  final String nextPage;
  final String nextPageInJs;
  final String nextChapterLink;

  factory ChapterRule.fromJson(Map<String, dynamic> j) => ChapterRule(
    baseUri: (j['baseUri'] ?? '').toString(),
    timeoutSec: (j['timeout'] as num?)?.toInt() ?? 15,
    title: (j['title'] ?? '').toString(),
    content: (j['content'] ?? '').toString(),
    paragraphTagClosed: j['paragraphTagClosed'] == true,
    paragraphTag: (j['paragraphTag'] ?? '').toString(),
    filterTxt: (j['filterTxt'] ?? '').toString(),
    filterTag: (j['filterTag'] ?? '').toString(),
    nextPage: (j['nextPage'] ?? '').toString(),
    nextPageInJs: (j['nextPageInJs'] ?? '').toString(),
    nextChapterLink: (j['nextChapterLink'] ?? '').toString(),
  );
}

/// 限流配置：秒/次数；全部可空，空 = 走全局设置（见 source_providers）。
class CrawlRule {
  const CrawlRule({
    this.concurrency,
    this.minIntervalSec,
    this.maxIntervalSec,
    this.maxAttempts,
    this.retryMinIntervalSec,
    this.retryMaxIntervalSec,
  });

  final int? concurrency;
  final int? minIntervalSec;
  final int? maxIntervalSec;
  final int? maxAttempts;
  final int? retryMinIntervalSec;
  final int? retryMaxIntervalSec;

  factory CrawlRule.fromJson(Map<String, dynamic>? j) => CrawlRule(
    concurrency: (j?['concurrency'] as num?)?.toInt(),
    minIntervalSec: (j?['minInterval'] as num?)?.toInt(),
    maxIntervalSec: (j?['maxInterval'] as num?)?.toInt(),
    maxAttempts: (j?['maxAttempts'] as num?)?.toInt(),
    retryMinIntervalSec: (j?['retryMinInterval'] as num?)?.toInt(),
    retryMaxIntervalSec: (j?['retryMaxInterval'] as num?)?.toInt(),
  );
}

/// 搜索结果条目。
class SourceSearchResult {
  const SourceSearchResult({
    required this.sourceId,
    required this.sourceName,
    required this.bookUrl,
    required this.bookName,
    this.author = '',
    this.category = '',
    this.latestChapter = '',
    this.lastUpdateTime = '',
    this.status = '',
    this.wordCount = '',
  });

  final String sourceId;
  final String sourceName;

  /// 详情页绝对 URL（书源引擎全链路的身份标识）。
  final String bookUrl;
  final String bookName;
  final String author;
  final String category;
  final String latestChapter;
  final String lastUpdateTime;
  final String status;
  final String wordCount;
}

/// 详情页信息。
class SourceBookInfo {
  const SourceBookInfo({
    required this.url,
    required this.bookName,
    required this.author,
    this.intro = '',
    this.category = '',
    this.coverUrl = '',
    this.latestChapter = '',
    this.latestChapterUrl = '',
    this.lastUpdateTime = '',
    this.status = '',
  });

  final String url;
  final String bookName;
  final String author;
  final String intro;
  final String category;
  final String coverUrl;
  final String latestChapter;
  final String latestChapterUrl;
  final String lastUpdateTime;
  final String status;
}

/// 目录章节。
class SourceChapter {
  const SourceChapter({
    required this.title,
    required this.url,
    required this.order,
  });

  final String title;
  final String url;
  final int order;
}

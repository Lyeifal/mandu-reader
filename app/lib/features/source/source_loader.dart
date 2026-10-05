/// 书源加载与校验（纯函数，零 Flutter 依赖；assets 读取由调用方喂字符串）。
///
/// 三层合并：内置 assets 源（sources.json） ← DB 覆盖层（同 sourceId 且
/// json 非空 → 整体替换规则）← enabled/disableReason 状态以 DB 为准
/// （内置源的 disabled 默认值仅在新装/未覆盖时生效）。
library;

import 'dart:convert';

import 'source_models.dart';
import 'source_ops.dart';
import 'source_selector.dart';

/// 解析 sources.json 内容（平铺数组）。
List<SourceRule> parseRulesJson(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! List) throw const FormatException('书源文件必须是 JSON 数组');
  return [
    for (final e in decoded)
      SourceRule.fromJson(
        (e as Map)['sourceId']?.toString() ?? '',
        e.cast<String, dynamic>(),
      ),
  ];
}

/// 源状态覆盖（DB 行，json 为空 = 仅状态覆盖）。
class SourceOverride {
  const SourceOverride({
    required this.sourceId,
    this.json = '',
    this.enabled,
    this.disableReason = '',
  });

  final String sourceId;

  /// 非空 = 用户自定义/替换规则（完整 sources.json 单条格式）。
  final String json;
  final bool? enabled;
  final String disableReason;
}

/// 合并内置源与 DB 覆盖层。
List<SourceRule> mergeOverrides(
  List<SourceRule> builtin,
  List<SourceOverride> overrides,
) {
  final byId = {for (final r in builtin) r.sourceId: r};
  for (final o in overrides) {
    final base = byId[o.sourceId];
    if (o.json.trim().isNotEmpty) {
      // 用户源整体替换（保持 sourceId）；注意不能 continue——
      // 启停状态合并必须随后生效，否则源管理页拨开关会在下次重算时弹回
      try {
        final decoded = jsonDecode(o.json);
        if (decoded is Map) {
          decoded['sourceId'] = o.sourceId;
          byId[o.sourceId] = SourceRule.fromJson(
            o.sourceId,
            decoded.cast<String, dynamic>(),
          );
        }
      } on Object {
        // 坏 JSON：忽略替换，保留内置并禁用
        byId[o.sourceId] = _disabledCopy(
          base ?? _placeholder(o.sourceId),
          '用户规则 JSON 解析失败',
        );
        continue;
      }
    }
    if (base == null) continue;
    byId[o.sourceId] = SourceRule(
      sourceId: base.sourceId,
      name: base.name,
      siteUrl: base.siteUrl,
      comment: base.comment,
      group: base.group,
      language: base.language,
      needProxy: base.needProxy,
      // DB 的 enabled 列 ↔ 规则的 disabled 取反；未设置沿用内置默认
      disabled: o.enabled == null ? base.disabled : !o.enabled!,
      disableReason: o.disableReason.isNotEmpty
          ? o.disableReason
          : base.disableReason,
      search: base.search,
      book: base.book,
      toc: base.toc,
      chapter: base.chapter,
      crawl: base.crawl,
    );
  }
  return byId.values.toList()..sort((a, b) => a.sourceId.compareTo(b.sourceId));
}

SourceRule _disabledCopy(SourceRule r, String reason) => SourceRule(
  sourceId: r.sourceId,
  name: r.name,
  siteUrl: r.siteUrl,
  comment: r.comment,
  group: r.group,
  language: r.language,
  needProxy: r.needProxy,
  disabled: true,
  disableReason: reason,
  search: r.search,
  book: r.book,
  toc: r.toc,
  chapter: r.chapter,
  crawl: r.crawl,
);

SourceRule _placeholder(String id) => SourceRule(
  sourceId: id,
  name: id,
  siteUrl: '',
  comment: '',
  group: 'custom',
  language: '',
  needProxy: false,
  disabled: true,
  disableReason: 'missing',
  book: BookRule.fromJson(const {}),
  toc: TocRule.fromJson(const {}, ''),
  chapter: ChapterRule.fromJson(const {}),
  crawl: const CrawlRule(),
);

/// 导入校验：结构 + 链语法 + 选择器可编译。返回错误列表（空 = 合法）。
List<String> validateRule(SourceRule rule, OpRegistry ops) {
  final errs = rule.validate();
  final queries = <String>[
    if (rule.search != null) ...[
      rule.search!.result,
      rule.search!.bookNameSel,
      rule.search!.author,
      rule.search!.category,
      rule.search!.latestChapter,
      rule.search!.lastUpdateTime,
      rule.search!.status,
      rule.search!.wordCount,
      rule.search!.nextPage,
    ],
    rule.book.bookNameSel,
    rule.book.author,
    rule.book.intro,
    rule.book.category,
    rule.book.coverUrl,
    rule.book.latestChapter,
    rule.book.latestChapterUrl,
    rule.book.lastUpdateTime,
    rule.book.status,
    rule.toc.list,
    rule.toc.item,
    rule.toc.nextPage,
    rule.chapter.title,
    rule.chapter.content,
    rule.chapter.filterTag,
    rule.chapter.nextPage,
    rule.chapter.nextPageInJs,
  ];
  for (final q in queries) {
    final t = q.trim();
    if (t.isEmpty) continue;
    // 算子存在性
    for (final name in SelectorEngine.chainOpNames(t)) {
      if (!ops.has(name)) errs.add('未知算子 @$name: $t');
    }
    // 选择器可编译（对空文档跑一次；@op 纯链无选择器段时跳过）
    final sel = SelectorEngine.stripChain(t).trim();
    if (sel.isEmpty) continue;
    try {
      SelectorEngine().select(_emptyDoc, t);
    } on Object catch (e) {
      errs.add('选择器无效「$sel」: ${e.toString().split('\n').first}');
    }
  }
  return errs;
}

// 预检用小文档（包级单例）
final _emptyDoc = parseHtml('<html><head></head><body></body></html>');

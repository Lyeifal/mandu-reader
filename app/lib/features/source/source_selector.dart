/// 选择器与提取层（纯函数，零 Flutter 依赖）。
///
/// 语义对照 so-novel HtmlExtractor：
/// - 查询串 = `<selector>[@attr][@op:...]`；`@` 前的选择器按前缀分流
///   CSS（package:html querySelectorAll）/ XPath（自写子集，source_xpath.dart）
/// - 提取类型：`@href`/`@src` → 绝对链接；`meta[` 前缀 → attr('content')；其余 text
/// - 多元素 text 以空格连接（jsoup Elements.text()）；html 为 innerHtml 拼接；
///   多元素 attr 取首个（jsoup Elements.attr()）
/// - 提取结果再过 `@op:` 链（source_ops.dart）
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser show parse;

import 'source_css.dart';
import 'source_ops.dart';
import 'source_xpath.dart';

enum ExtractKind { text, html, attrHref, attrSrc, attrContent }

class SelectorEngine {
  SelectorEngine({OpRegistry? ops}) : ops = ops ?? buildDefaultOps();

  final OpRegistry ops;

  /// `@` 前的纯选择器部分（无链时原样返回；`@` 在位置 0 = 纯算子链，
  /// 无选择器部分，返回空串——如 `@op:quanbenSearchUrl()` 整体即链）。
  /// `@` 必须在方括号/圆括号之外——XPath 谓词 `[@attr='v']` 不是链分隔符。
  static String stripChain(String query) {
    final i = _firstAtOutsideBrackets(query);
    return i >= 0 ? query.substring(0, i) : query;
  }

  static int _firstAtOutsideBrackets(String q) {
    var depth = 0;
    var quote = '';
    for (var i = 0; i < q.length; i++) {
      final c = q[i];
      if (quote.isNotEmpty) {
        if (c == quote) quote = '';
        continue;
      }
      if (c == '\'' || c == '"') {
        quote = c;
      } else if (c == '[' || c == '(') {
        depth++;
      } else if (c == ']' || c == ')') {
        depth--;
      } else if (c == '@' && depth == 0) {
        return i;
      }
    }
    return -1;
  }

  /// 提取类型判定（so-novel getContentType 同款）。
  static ExtractKind kindOf(String query) {
    if (query.contains('@href')) return ExtractKind.attrHref;
    if (query.contains('@src')) return ExtractKind.attrSrc;
    if (query.startsWith('meta[')) return ExtractKind.attrContent;
    return ExtractKind.text;
  }

  /// 链上出现的算子名（导入预检用）。每段可能带 '@' 前缀，先剥再判。
  static List<String> chainOpNames(String query) {
    final at = _firstAtOutsideBrackets(query);
    if (at < 0) return const [];
    final rest = query.substring(at + 1);
    return [
      for (final raw in rest.split(RegExp(r'(?=@\w+:)')))
        if ((raw.startsWith('@') ? raw.substring(1) : raw).startsWith('op:'))
          (raw.startsWith('@') ? raw.substring(1) : raw)
              .substring(3)
              .split('(')
              .first
              .split(':')
              .first
              .trim(),
    ];
  }

  /// 查询元素（CSS / XPath 自动分流）。接受 Document 或 Element。
  List<dom.Element> select(dom.Node root, String query) {
    final sel = stripChain(query).trim();
    if (sel.isEmpty) return const [];
    final isXPath = sel.startsWith('/') || sel.startsWith('(');
    if (isXPath) {
      final ctx = root is dom.Document ? root.documentElement : root;
      if (ctx is! dom.Element) return const [];
      return xpathSelect(ctx, sel);
    }
    try {
      return cssSelect(root, sel);
    } on Object catch (e) {
      throw FormatException(
        'CSS 选择器无效「$sel」: ${e.toString().split('\n').first}',
      );
    }
  }

  /// 提取：选择 → 按类型取内容 → 过 `@op:` 链。
  String extract(
    dom.Node root,
    String query, {
    ExtractKind? kind,
    String baseUrl = '',
    String sourceId = '',
  }) {
    if (query.trim().isEmpty) return '';
    final els = select(root, query);
    if (els.isEmpty) return '';
    final k = kind ?? kindOf(query);
    final String raw;
    if (els.length == 1) {
      raw = _contentOf(els.first, k);
    } else {
      raw = switch (k) {
        ExtractKind.text => els.map((e) => e.text.trim()).join(' '),
        ExtractKind.html => els.map((e) => e.innerHtml).join(),
        ExtractKind.attrHref => els.first.attributes['href'] ?? '',
        ExtractKind.attrSrc => els.first.attributes['src'] ?? '',
        ExtractKind.attrContent => els.first.attributes['content'] ?? '',
      };
    }
    final absolved = switch (k) {
      ExtractKind.attrHref => absUrl(raw, baseUrl),
      ExtractKind.attrSrc => absUrl(raw, baseUrl),
      _ => raw,
    };
    return runChain(query, absolved, baseUrl: baseUrl, sourceId: sourceId);
  }

  /// 对已有内容执行链（extractContent 语义：不再选择，只跑 DSL）。
  String runChainOn(
    String query,
    String value, {
    String baseUrl = '',
    String sourceId = '',
  }) => runChain(query, value, baseUrl: baseUrl, sourceId: sourceId);

  /// 执行 `@op:` 链；`@href/@src` 步跳过（提取类型已处理）。
  String runChain(
    String query,
    String input, {
    String baseUrl = '',
    String sourceId = '',
  }) {
    final steps = _chainSteps(query);
    var r = input;
    for (final step in steps) {
      switch (step) {
        case _AttrStep():
          break;
        case _OpStep(:final name, :final args):
          r = ops.run(
            name,
            r,
            args,
            OpContext(sourceId: sourceId, baseUrl: baseUrl),
          );
      }
    }
    return r;
  }
}

sealed class _Step {}

class _AttrStep extends _Step {}

class _OpStep extends _Step {
  _OpStep(this.name, this.args);

  final String name;
  final List<Object?> args;
}

/// 把查询串拆成 [选择器, 步骤…]（`@` 须在方括号之外）。
List<_Step> _chainSteps(String query) {
  final at = SelectorEngine._firstAtOutsideBrackets(query);
  if (at < 0) return const [];
  // at == 0：整条即链（纯 @op: 算子串），去掉前缀 '@' 后与 at > 0 同构。
  // lookahead split 会在每一段（除首段）保留 '@' 前缀，剥掉再判定——
  // 否则多算子链的第二段起会抛「未知步骤 @op」（96读书/全本链曾因此必炸）
  final rest = query.substring(at + 1);
  final parts = rest
      .split(RegExp(r'(?=@\w+:)'))
      .where((s) => s.isNotEmpty)
      .map((s) => (s.startsWith('@') ? s.substring(1) : s).trim());
  final steps = <_Step>[];
  for (final p in parts) {
    final idx = p.indexOf(':');
    final name = idx < 0 ? p.trim() : p.substring(0, idx).trim();
    if (name == 'op') {
      final parsed = parseOpStep(p.substring(idx + 1));
      steps.add(_OpStep(parsed.name, parsed.args));
    } else if (name == 'href' || name == 'src') {
      steps.add(_AttrStep());
    } else {
      // 转换后的规则不应再有 @js/@java；未知段直接报错，防静默错链
      throw FormatException('规则链含未知步骤「$name」（仅支持 @href/@src/@op:）: $query');
    }
  }
  return steps;
}

String _contentOf(dom.Element el, ExtractKind kind) => switch (kind) {
  ExtractKind.text => el.text.trim(),
  ExtractKind.html => el.innerHtml,
  ExtractKind.attrHref => el.attributes['href'] ?? '',
  ExtractKind.attrSrc => el.attributes['src'] ?? '',
  ExtractKind.attrContent => el.attributes['content'] ?? '',
};

/// HTML 字符串解析为可查询文档。baseUri 不由文档持有——
/// 调用方在 extract 时显式传 baseUrl（规则 baseUri 或实际响应 URL）。
dom.Document parseHtml(String html) => html_parser.parse(html);

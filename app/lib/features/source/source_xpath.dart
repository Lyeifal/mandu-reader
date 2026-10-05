/// 最小 XPath 子集求值器（纯函数，零 Flutter 依赖）。
///
/// so-novel 规则全库仅 4 处真 XPath，支持语法：
/// - `/` 子轴、`//`  descendant 轴
/// - 步：tag 或 `*`
/// - 谓词：`[@attr='v']`、`[@attr!="v"]`、`[@attr]`、`[n]`（1 基，per-parent）、
///   `[last()]`、`[not(text()='v')]`，支持 ` and ` 链
/// - 结尾 `/text()`（提取语义由上层决定，这里等价于选中该元素）
library;

import 'package:html/dom.dart' as dom;

/// 在 [root] 上求 XPath，返回匹配元素（文档序）。
List<dom.Element> xpathSelect(dom.Element root, String xpath) {
  var q = xpath.trim();
  const textTail = '/text()';
  if (q.endsWith(textTail)) q = q.substring(0, q.length - textTail.length);
  final steps = _parseSteps(q);
  var current = [root];
  var first = true;
  for (final step in steps) {
    final next = <dom.Element>[];
    for (final el in current) {
      // 绝对路径首步允许根自身匹配（/html 从 documentElement 起步）
      if (first &&
          !step.descendant &&
          step.matchesTag(el) &&
          step.applyPredicates([el]).isNotEmpty) {
        next.add(el);
      }
      final candidates = step.descendant ? _allDescendants(el) : el.children;
      final matched = step.applyPredicates(
        candidates.where(step.matchesTag).toList(),
      );
      next.addAll(matched);
    }
    current = next;
    first = false;
  }
  return current;
}

List<dom.Element> _allDescendants(dom.Element el) {
  final out = <dom.Element>[];
  void walk(dom.Element e) {
    for (final c in e.children) {
      out.add(c);
      walk(c);
    }
  }

  walk(el);
  return out;
}

/// 顶层 ' and ' 拆分（本子集无嵌套 and；引号内出现 and 的规则不存在）。
List<String> _splitAnd(String cond) => cond
    .split(' and ')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// 位置谓词按父分组应用：fn 返回 null 表示该组不取。
List<dom.Element> _positionalPerParent(
  List<dom.Element> els,
  dom.Element? Function(List<dom.Element> group) fn,
) {
  final byParent = <dom.Node?, List<dom.Element>>{};
  for (final e in els) {
    byParent.putIfAbsent(e.parentNode, () => []).add(e);
  }
  final out = <dom.Element>[];
  for (final group in byParent.values) {
    final pick = fn(group);
    if (pick != null) out.add(pick);
  }
  return out;
}

class _Step {
  _Step(this.tag, this.descendant, this.rawConds);

  final String tag; // '*' = 任意
  final bool descendant;
  final List<String> rawConds;

  bool matchesTag(dom.Element el) =>
      tag == '*' || el.localName?.toLowerCase() == tag.toLowerCase();

  /// 谓词应用。非位置谓词（@attr/[@attr]/not(text())）对整个候选集过滤；
  /// 位置谓词（[n]/[last()]）按 **per-parent** 语义——同一父下的匹配子集中
  /// 取第 n 个（XPath 标准；此前对扁平 descendant 列表取全局第 1 个是错的：
  /// //div[@class='x'][1] 应是「每个父下第一个」，不是全文档第一个）。
  /// 复合谓词 `[a and b]` 拆成串行条件。
  List<dom.Element> applyPredicates(List<dom.Element> candidates) {
    if (rawConds.isEmpty) return candidates;
    var result = candidates;
    final conds = rawConds.expand(_splitAnd).toList();
    for (final cond in conds) {
      if (cond == 'last()') {
        result = _positionalPerParent(result, (g) => g.last);
      } else if (RegExp(r'^\d+$').hasMatch(cond)) {
        final n = int.parse(cond);
        result = _positionalPerParent(
          result,
          (g) => (n >= 1 && n <= g.length) ? g[n - 1] : null,
        );
      } else if (cond.startsWith('not(') && cond.endsWith(')')) {
        // 注意：「!=?」会让 ! 变成必选（裸 = 永远不匹配）——
        // 「!?=」才是「可选 ! + 必选 =」的语义（2026-10-04 review 实锤）
        final m = RegExp(
          '^not\\(text\\(\\)\\s*!?\\s*=\\s*["\']'
          '([^"\']*)'
          '["\']\\)\$',
        ).firstMatch(cond);
        if (m != null) {
          final v = m.group(1)!;
          result = result.where((e) => e.text.trim() != v).toList();
        }
      } else {
        final m = RegExp('^@([\\w-]+)\\s*(=|!=)\\s*["\']([^"\']*)["\']\$')
            .firstMatch(cond);
        if (m != null) {
          final attr = m.group(1)!;
          final want = m.group(3)!;
          final neq = m.group(2) == '!=';
          result = result.where((e) {
            final has = e.attributes.containsKey(attr);
            if (neq) return !has || e.attributes[attr] != want;
            return has && e.attributes[attr] == want;
          }).toList();
        } else if (RegExp('^@[\\w-]+\\s*\$').hasMatch(cond)) {
          final attr = cond.substring(1).trim();
          result = result.where((e) => e.attributes.containsKey(attr)).toList();
        }
      }
    }
    return result;
  }
}

/// 按 / 与 // 切步（方括号深度感知），每步解析 tag+谓词。
List<_Step> _parseSteps(String xpath) {
  final steps = <_Step>[];
  var i = 0;
  var descendant = false;
  final n = xpath.length;

  // 处理开头的 / 或 //
  if (xpath.startsWith('//')) {
    descendant = true;
    i = 2;
  } else if (xpath.startsWith('/')) {
    i = 1;
  } else {
    throw FormatException('XPath 必须以 / 或 // 开头: $xpath');
  }

  while (i < n) {
    final start = i;
    var depth = 0;
    while (i < n && (depth > 0 || (xpath[i] != '/'))) {
      if (xpath[i] == '[') depth++;
      if (xpath[i] == ']') depth--;
      i++;
    }
    final seg = xpath.substring(start, i);
    if (seg.isNotEmpty) steps.add(_parseStep(seg, descendant));
    if (i < n) {
      descendant = xpath.startsWith('//', i);
      i += descendant ? 2 : 1;
    }
  }
  return steps;
}

_Step _parseStep(String seg, bool descendant) {
  var tag = '';
  var i = 0;
  while (i < seg.length && seg[i] != '[') {
    tag += seg[i];
    i++;
  }
  tag = tag.trim();
  if (tag.isEmpty) tag = '*';
  final conds = <String>[];
  while (i < seg.length && seg[i] == '[') {
    final end = seg.indexOf(']', i);
    if (end < 0) throw FormatException('XPath 谓词未闭合: $seg');
    conds.add(seg.substring(i + 1, end));
    i = end + 1;
  }
  return _Step(tag, descendant, conds);
}

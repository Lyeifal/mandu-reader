/// 迷你 CSS 选择器引擎（纯函数，零 Flutter 依赖）。
///
/// 存在的理由：package:html 的 querySelectorAll 不实现 `:nth-of-type`
/// （PseudoClassFunctionSelector 抛 UnimplementedError），且对未加引号的
/// 含 `:`/`;` 属性值（`p[style=font-size:12px;]`）解析失败——书源规则
/// `:nth-of-type` 7 处、`:not(` 8 处真实使用，不能降级。
///
/// 支持子集（覆盖 sources.json 全量选择器，回归测试钉死）：
/// - 组合器：后代空格、`>` 子代、`,` 分组
/// - 复合：tag、`*`、`#id`、`.class`、`[attr]`、`[attr=v]`（v 可带引号或裸值）
/// - 伪类：`:nth-child(N|an+b|odd|even)`、`:nth-of-type(...)`、
///   `:nth-last-child(...)`、`:nth-last-of-type(...)`、`:not(简单复合)`
/// 语义对齐 jsoup：元素集不含根自身；多组结果按文档序去重。
library;

import 'package:html/dom.dart' as dom;

/// 查询 [root] 的后代元素（不含 root 自身）。
List<dom.Element> cssSelect(dom.Node root, String selector) {
  final groups = _splitTopLevel(selector, ',');
  final matched = <dom.Element>[];
  final seen = <dom.Element>{};
  for (final g in groups) {
    final steps = _parseGroup(g.trim());
    if (steps == null) {
      throw FormatException('CSS 选择器无效「$selector」');
    }
    var current = <dom.Node>[root];
    for (final step in steps) {
      final next = <dom.Element>[];
      for (final ctx in current) {
        final candidates = switch (step.combinator) {
          _Comb.child => _childElements(ctx),
          _Comb.sibling => _followingSiblings(ctx),
          _Comb.descendant => _descendantElements(ctx),
        };
        for (final el in candidates) {
          if (step.compound.matches(el) && !next.contains(el)) next.add(el);
        }
      }
      current = next;
    }
    for (final el in current.whereType<dom.Element>()) {
      if (seen.add(el)) matched.add(el);
    }
  }
  return _sortDocumentOrder(matched);
}

List<dom.Element> _childElements(dom.Node node) =>
    node.nodes.whereType<dom.Element>().toList();

/// `~` 后继兄弟：同一父节点下位于 ctx 之后的元素。
List<dom.Element> _followingSiblings(dom.Node node) {
  final parent = node.parentNode;
  if (parent == null) return const [];
  final sibs = parent.nodes.whereType<dom.Element>().toList();
  if (node is! dom.Element) return const [];
  final i = sibs.indexOf(node);
  if (i < 0) return const [];
  return sibs.sublist(i + 1);
}

enum _Comb { descendant, child, sibling }

List<dom.Element> _descendantElements(dom.Node node) {
  final out = <dom.Element>[];
  void walk(dom.Node n) {
    for (final c in n.nodes) {
      if (c is dom.Element) {
        out.add(c);
        walk(c);
      }
    }
  }

  walk(node);
  return out;
}

/// 文档序排序：按「从根到元素的兄弟下标路径」字典序。
List<dom.Element> _sortDocumentOrder(List<dom.Element> els) {
  List<int> path(dom.Element el) {
    final p = <int>[];
    dom.Node? cur = el;
    while (cur?.parentNode != null) {
      final parent = cur!.parentNode!;
      final sibs = parent.nodes.whereType<dom.Element>().toList();
      p.add(sibs.indexOf(cur as dom.Element));
      cur = parent;
    }
    return p.reversed.toList();
  }

  final indexed = els.map((e) => (el: e, p: path(e))).toList();
  int cmp(
    ({dom.Element el, List<int> p}) a,
    ({dom.Element el, List<int> p}) b,
  ) {
    final n = a.p.length < b.p.length ? a.p.length : b.p.length;
    for (var i = 0; i < n; i++) {
      if (a.p[i] != b.p[i]) return a.p[i] - b.p[i];
    }
    return a.p.length - b.p.length;
  }

  indexed.sort(cmp);
  return indexed.map((e) => e.el).toList();
}

/// 顶层切分（方括号/圆括号深度感知）。
List<String> _splitTopLevel(String s, String sep) {
  final out = <String>[];
  var depth = 0;
  var cur = StringBuffer();
  var quote = '';
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quote.isNotEmpty) {
      cur.write(c);
      if (c == quote) quote = '';
      continue;
    }
    if (c == '\'' || c == '"') {
      quote = c;
      cur.write(c);
    } else if (c == '[' || c == '(') {
      depth++;
      cur.write(c);
    } else if (c == ']' || c == ')') {
      depth--;
      cur.write(c);
    } else if (depth == 0 && c == sep) {
      out.add(cur.toString());
      cur = StringBuffer();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString());
  return out;
}

class _Compound {
  _Compound({
    this.tag = '',
    this.id = '',
    this.classes = const [],
    this.attrs = const [],
    this.pseudos = const [],
  });

  final String tag; // '' = 任意；'*' 由调用方归一为 ''
  final String id;
  final List<String> classes;
  final List<(String name, String? value)> attrs; // value null = 存在性
  final List<({String name, String? arg})> pseudos;

  bool matches(dom.Element el) {
    if (tag.isNotEmpty && el.localName?.toLowerCase() != tag.toLowerCase()) {
      return false;
    }
    if (id.isNotEmpty && el.id != id) return false;
    for (final c in classes) {
      if (!el.classes.contains(c)) return false;
    }
    for (final (name, value) in attrs) {
      if (!el.attributes.containsKey(name)) return false;
      if (value != null && el.attributes[name] != value) return false;
    }
    for (final p in pseudos) {
      if (!_matchPseudo(el, p.name, p.arg)) return false;
    }
    return true;
  }
}

bool _matchPseudo(dom.Element el, String name, String? arg) {
  final parent = el.parentNode;
  final sibs = parent == null
      ? <dom.Element>[el]
      : parent.nodes.whereType<dom.Element>().toList();
  final idx = sibs.indexOf(el) + 1; // 1 基
  switch (name) {
    case 'nth-child':
      return _matchNth(idx, arg ?? '');
    case 'nth-last-child':
      return _matchNth(sibs.length - idx + 1, arg ?? '');
    case 'nth-of-type':
      final same = sibs.where((e) => e.localName == el.localName).toList();
      return _matchNth(same.indexOf(el) + 1, arg ?? '');
    case 'nth-last-of-type':
      final same = sibs.where((e) => e.localName == el.localName).toList();
      return _matchNth(same.length - same.indexOf(el), arg ?? '');
    case 'first-child':
      return idx == 1;
    case 'last-child':
      return idx == sibs.length;
    case 'only-child':
      return sibs.length == 1;
    default:
      return false;
  }
}

/// an+b 匹配（odd/even/纯数字/an+b/an-b/-n+b 等形式）。
bool _matchNth(int index, String expr) {
  var e = expr.trim().toLowerCase().replaceAll(' ', '');
  if (e == 'odd') return index.isOdd;
  if (e == 'even') return index.isEven;
  if (!e.contains('n')) {
    final n = int.tryParse(e);
    return n != null && index == n;
  }
  // 形如 an+b / an-b / n+b / -n+b / n
  final parts = e.split('n');
  if (parts.length != 2) return false;
  final a = parts[0].isEmpty
      ? 1
      : parts[0] == '-'
      ? -1
      : int.tryParse(parts[0]);
  if (a == null) return false;
  final b = parts[1].isEmpty ? 0 : int.tryParse(parts[1]);
  if (b == null) return false;
  if (a == 0) return index == b;
  final diff = index - b;
  return diff % a == 0 && diff ~/ a >= 0;
}

class _Step {
  _Step(this.combinator, this.compound);

  final _Comb combinator;
  final _Compound compound;
}

/// 解析一组（无逗号）为步序列；失败返回 null。
List<_Step>? _parseGroup(String group) {
  if (group.isEmpty) return null;
  final steps = <_Step>[];
  var i = 0;
  var combinator = _Comb.descendant;
  while (i < group.length) {
    // 读取组合器：> 子代、~ 后继兄弟、空格后代；显式组合器只作用于紧邻一步
    var sawExplicit = false;
    while (i < group.length &&
        (group[i] == ' ' || group[i] == '>' || group[i] == '~')) {
      if (group[i] == '>') {
        combinator = _Comb.child;
        sawExplicit = true;
      } else if (group[i] == '~') {
        combinator = _Comb.sibling;
        sawExplicit = true;
      }
      i++;
    }
    if (!sawExplicit && combinator != _Comb.descendant) {
      combinator = _Comb.descendant;
    }
    if (i >= group.length) break;
    final start = i;
    var depth = 0;
    var quote = '';
    while (i < group.length) {
      final c = group[i];
      if (quote.isNotEmpty) {
        if (c == quote) quote = '';
      } else if (c == '\'' || c == '"') {
        quote = c;
      } else if (c == '[' || c == '(') {
        depth++;
      } else if (c == ']' || c == ')') {
        depth--;
      } else if (depth == 0 && (c == ' ' || c == '>')) {
        break;
      }
      i++;
    }
    final compoundStr = group.substring(start, i);
    final compound = _parseCompound(compoundStr);
    if (compound == null) return null;
    steps.add(_Step(combinator, compound));
    combinator = _Comb.descendant;
  }
  if (steps.isEmpty) return null;
  return steps;
}

_Compound? _parseCompound(String s) {
  var tag = '';
  var id = '';
  final classes = <String>[];
  final attrs = <(String, String?)>[];
  final pseudos = <({String name, String? arg})>[];
  var i = 0;
  final n = s.length;
  final nots = <_Compound>[];
  // tag 或 *
  if (i < n && (s[i] == '*' || RegExp(r'[a-zA-Z]').hasMatch(s[i]))) {
    final m = RegExp(r'^(\*|[a-zA-Z][\w-]*)').firstMatch(s.substring(i));
    if (m != null) {
      tag = m.group(1)! == '*' ? '' : m.group(1)!;
      i += m.group(0)!.length;
    }
  }
  while (i < n) {
    final c = s[i];
    if (c == '#') {
      final m = RegExp(r'^#([\w-]+)').firstMatch(s.substring(i));
      if (m == null) return null;
      id = m.group(1)!;
      i += m.group(0)!.length;
    } else if (c == '.') {
      final m = RegExp(r'^\.([\w-]+)').firstMatch(s.substring(i));
      if (m == null) return null;
      classes.add(m.group(1)!);
      i += m.group(0)!.length;
    } else if (c == '[') {
      final end = s.indexOf(']', i);
      if (end < 0) return null;
      final inner = s.substring(i + 1, end).trim();
      final eq = inner.indexOf('=');
      if (eq < 0) {
        attrs.add((inner, null));
      } else {
        final name = inner.substring(0, eq).trim();
        var value = inner.substring(eq + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith('\'') && value.endsWith('\'')))) {
          value = value.substring(1, value.length - 1);
        }
        attrs.add((name, value));
      }
      i = end + 1;
    } else if (c == ':') {
      final m = RegExp(r'^:([\w-]+)(?:\(([^()]*)\))?')
          .firstMatch(s.substring(i));
      if (m == null) return null;
      final name = m.group(1)!;
      final arg = m.group(2);
      if (name == 'not') {
        if (arg == null) return null;
        final inner = _parseCompound(arg.trim());
        if (inner == null) return null;
        nots.add(inner);
      } else {
        pseudos.add((name: name, arg: arg));
      }
      i += m.group(0)!.length;
      continue;
    } else {
      return null;
    }
  }
  final compound = _Compound(
    tag: tag,
    id: id,
    classes: classes,
    attrs: attrs,
    pseudos: pseudos,
  );
  return nots.isEmpty ? compound : _CompoundWithNot(compound, nots);
}

class _CompoundWithNot extends _Compound {
  _CompoundWithNot(this.base, this.nots)
    : super(
        tag: base.tag,
        id: base.id,
        classes: base.classes,
        attrs: base.attrs,
        pseudos: base.pseudos,
      );

  final _Compound base;
  final List<_Compound> nots;

  @override
  bool matches(dom.Element el) {
    if (!super.matches(el)) return false;
    return !nots.any((n) => n.matches(el));
  }
}

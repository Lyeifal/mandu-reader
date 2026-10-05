/// `@op:` 算子层（纯函数，零 Flutter 依赖）。
///
/// so-novel 的 `@js:`/`@java:` 短脚本已全部移植为这里的具名算子
/// （原语意对照见 assets/rules/NOTICE.md）。规则链语法：
/// `<selector>[@attr][@op:name(args)]...`——上一步字符串输出作下一步输入。
library;

import 'dart:convert';
import 'dart:math';

/// 算子执行上下文。
class OpContext {
  const OpContext({required this.sourceId, required this.baseUrl});

  final String sourceId;

  /// 当前文档 baseUri（规则 baseUri 或实际响应 URL）。
  final String baseUrl;
}

typedef OpFn = String Function(String input, List<Object?> args, OpContext ctx);

/// 算子注册表；未知算子抛带名异常（单源测试据此报告）。
class OpRegistry {
  final _ops = <String, OpFn>{};

  void register(String name, OpFn fn) => _ops[name] = fn;

  bool has(String name) => _ops.containsKey(name);

  Set<String> get names => _ops.keys.toSet();

  String run(String name, String input, List<Object?> args, OpContext ctx) {
    final fn = _ops[name];
    if (fn == null) {
      throw FormatException('书源「${ctx.sourceId}」使用了未实现的算子: $name');
    }
    return fn(input, args, ctx);
  }
}

/// 默认算子全集。
OpRegistry buildDefaultOps() {
  final reg = OpRegistry();

  // JS String.replace(string, …)：仅首个；replaceAll：全部。
  reg.register('replace', (r, args, _) {
    final a = args[0]?.toString() ?? '';
    final b = args[1]?.toString() ?? '';
    if (a.isEmpty || !r.contains(a)) return r;
    return r.replaceFirst(a, b);
  });
  reg.register('replaceAll', (r, args, _) {
    final a = args[0]?.toString() ?? '';
    if (a.isEmpty) return r;
    return r.replaceAll(a, args[1]?.toString() ?? '');
  });

  // JS String.replace(RegExp, rep)：flags 无 g = 首个；$1..$9 组引用。
  reg.register('regexReplace', (r, args, _) {
    final re = args[0];
    if (re is! _Re) return r;
    final rep = args[1]?.toString() ?? '';
    String subst(Match m) {
      var out = rep;
      for (var i = 1; i <= 9; i++) {
        out = out.replaceAll(
          '\$$i',
          (i <= m.groupCount && m.group(i) != null) ? m.group(i)! : '',
        );
      }
      return out.replaceAll('\$\$', '\$');
    }

    return re.global
        ? r.replaceAllMapped(re.re, subst)
        : re.re.firstMatch(r) != null
        ? r.replaceFirstMapped(re.re, subst)
        : r;
  });

  reg.register('regexExtract', (r, args, _) {
    final re = args[0];
    final n = (args[1] as num?)?.toInt() ?? 1;
    if (re is! _Re) return '';
    final m = re.re.firstMatch(r);
    if (m == null || n > m.groupCount) return '';
    return m.group(n) ?? '';
  });

  reg.register('prefix', (r, args, _) => '${args[0]?.toString() ?? ''}$r');
  reg.register('suffix', (r, args, _) => '$r${args[0]?.toString() ?? ''}');
  reg.register('strip', (r, _, _) => r.trim());
  reg.register('stripCtl', (r, _, _) => r.replaceAll(RegExp('[\r\n\t]'), ''));

  reg.register('absUrl', (r, args, ctx) {
    final base = (args.isNotEmpty && args[0]?.toString().isNotEmpty == true)
        ? args[0].toString()
        : ctx.baseUrl;
    return absUrl(r.trim(), base);
  });

  // @java:base64.decode() 移植：逐行 trim → 跳过空行 → base64 解码 → UTF-8 拼接。
  reg.register('base64Lines', (r, _, _) {
    final out = StringBuffer();
    for (final line in r.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        out.write(utf8.decode(base64.decode(t), allowMalformed: true));
      } on Object {
        // 单行解码失败不拖垮整体（混有明文行时保留原文）
        out.write(t);
      }
    }
    return out.toString();
  });

  // 96读书链：<script>qsbs.bb('B64')</script> → 原文 B64（再 @op:base64Lines）。
  reg.register('qsbsExtract', (r, _, _) {
    final re = RegExp(
      r"<script>\s*document\.writeln\(qsbs\.bb\('([^']+)'\)\);\s*</script>",
    );
    return r.replaceAllMapped(re, (m) => m.group(1)!);
  });

  // 燃文/梦书内联版：同上但直接解出文本（qsbs.bb = 标准 base64 → UTF-8）。
  reg.register('qsbsDecode', (r, _, _) {
    final re = RegExp(
      r"<script>\s*document\.writeln\(qsbs\.bb\('([^']+)'\)\);\s*</script>",
    );
    return r.replaceAllMapped(re, (m) {
      try {
        return utf8.decode(base64.decode(m.group(1)!), allowMalformed: true);
      } on Object {
        return '';
      }
    });
  });

  // 全本 JSONP：search({...}) 拆包取字段。
  reg.register('jsonpField', (r, args, _) {
    final field = args[0]?.toString() ?? 'content';
    final m = RegExp(r'search\((.+)\)').firstMatch(r);
    if (m == null) return r;
    try {
      final o = jsonDecode(m.group(1)!);
      if (o is Map && o[field] != null) return o[field].toString();
    } on Object {
      // 落回原文
    }
    return r;
  });

  // 老幺：dd data-id 排序后拼接内部 <p> 块。
  reg.register('ddSortByDataId', (r, _, _) {
    final ddRe = RegExp(r'<dd\s+data-id="(\d+)">([\s\S]*?)</dd>');
    final dds =
        ddRe
            .allMatches(r)
            .map((m) => (id: int.parse(m.group(1)!), body: m.group(2)!))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final pRe = RegExp(r'<p>[\s\S]*?</p>');
    final out = StringBuffer();
    for (final dd in dds) {
      for (final p in pRe.allMatches(dd.body)) {
        out.write(p.group(0));
      }
    }
    return out.toString();
  });

  // 顶点：按 <style> 里 nth-child/nth-last-child display:none 计数，裁掉首尾隐藏 li。
  reg.register('filterHiddenLis', (r, _, _) {
    final preHidden = RegExp(
      r'\.section-list\.ycxsid>li:nth-child\(\d+\)\{display:none\}',
    ).allMatches(r).length;
    final afterHidden = RegExp(
      r'\.section-list\.ycxsid>li:nth-last-child\(\d+\)\{display:none\}',
    ).allMatches(r).length;
    final ulRe = RegExp(
      r'<ul[^>]*class="[^"]*\bsection-list\b[^"]*\bycxsid\b[^"]*"[^>]*>([\s\S]*?)</ul>',
    );
    return r.replaceAllMapped(ulRe, (m) {
      final liContent = m.group(1)!;
      final lis = RegExp(r'<li[\s\S]*?</li>')
          .allMatches(liContent)
          .map((e) => e.group(0)!)
          .toList();
      final keep = lis.sublist(
        preHidden.clamp(0, lis.length),
        lis.length - afterHidden.clamp(0, lis.length - preHidden),
      );
      return m.group(0)!.replaceFirst(liContent, keep.join());
    });
  });

  // 防御：多元素提取时取首个非空。
  reg.register('firstNonEmpty', (r, _, _) => r);

  // 全本小说网搜索签名（输入 keyword → 完整搜索 URL；移植自 quanben5 规则 @js）。
  reg.register('quanbenSearchUrl', (r, args, _) {
    const s = 'PXhw7UT1B0a9kQDKZsjIASmOezxYG4CHo5Jyfg2b8FLpEvRr3WtVnlqMidu6cN';
    final kw = Uri.encodeFull(r);
    final rnd = Random();
    final e = StringBuffer();
    for (final ch in kw.split('')) {
      final n = s.indexOf(ch);
      final c = n == -1 ? ch : s[(n + 3) % 62];
      e
        ..write(s[rnd.nextInt(62)])
        ..write(c)
        ..write(s[rnd.nextInt(62)]);
    }
    return 'https://quanben5.com/?c=book&a=search.json&callback=search&keywords=$r&b=${Uri.encodeFull(e.toString())}';
  });

  return reg;
}

/// 相对链接 → 绝对链接（jsoup absUrl 语义）。
String absUrl(String href, String base) {
  final h = href.trim();
  if (h.isEmpty) return '';
  if (h.startsWith('http://') || h.startsWith('https://')) return h;
  try {
    return Uri.parse(base).resolve(h).toString();
  } on Object {
    return h;
  }
}

/// 算子参数：字符串（单引号）/ 正则字面量 / 整数。
class _Re {
  _Re(this.re, this.global);

  final RegExp re;
  final bool global;
}

/// 解析算子一步 `name(args)` 或旧式 `name:args`，返回 (name, args)。
/// args 语法：'str'（\' 转义）、/pattern/flags（flags 支持 g i m s u）、整数。
({String name, List<Object?> args}) parseOpStep(String step) {
  final paren = step.indexOf('(');
  final colon = step.indexOf(':');
  final String name;
  final String argPart;
  if (paren >= 0 && (colon < 0 || paren < colon)) {
    name = step.substring(0, paren).trim();
    final end = step.endsWith(')') ? step.length - 1 : step.length;
    argPart = paren + 1 <= end ? step.substring(paren + 1, end) : '';
  } else if (colon >= 0) {
    name = step.substring(0, colon).trim();
    argPart = step.substring(colon + 1);
  } else {
    name = step.trim();
    argPart = '';
  }
  return (
    name: name,
    args: argPart.trim().isEmpty ? const [] : parseArgs(argPart),
  );
}

/// 顶层逗号切分（引号与正则字面量深度感知）。
List<Object?> parseArgs(String s) {
  final args = <Object?>[];
  var i = 0;
  final n = s.length;
  while (i < n) {
    while (i < n && (s[i] == ' ' || s[i] == ',')) {
      i++;
    }
    if (i >= n) break;
    if (s[i] == '\'') {
      final buf = StringBuffer();
      i++;
      while (i < n && s[i] != '\'') {
        if (s[i] == r'\' && i + 1 < n) {
          buf.write(s[i + 1]);
          i += 2;
        } else {
          buf.write(s[i]);
          i++;
        }
      }
      i++; // 跳过后引号
      args.add(buf.toString());
    } else if (s[i] == '/') {
      final buf = StringBuffer();
      i++;
      while (i < n && s[i] != '/') {
        if (s[i] == r'\' && i + 1 < n) {
          buf.write(s[i]);
          buf.write(s[i + 1]);
          i += 2;
        } else {
          buf.write(s[i]);
          i++;
        }
      }
      i++; // 跳过后斜杠
      var flags = '';
      while (i < n && RegExp(r'[a-z]').hasMatch(s[i])) {
        flags += s[i];
        i++;
      }
      args.add(
        _Re(
          RegExp(
            buf.toString(),
            caseSensitive: !flags.contains('i'),
            multiLine: flags.contains('m'),
            dotAll: flags.contains('s'),
            unicode: flags.contains('u'),
          ),
          flags.contains('g'),
        ),
      );
    } else {
      final m = RegExp(r'\d+').matchAsPrefix(s, i);
      if (m != null) {
        args.add(int.parse(m.group(0)!));
        i = m.end;
      } else {
        // 裸词（op 名引用等）：读到逗号/结尾
        final start = i;
        while (i < n && s[i] != ',') {
          i++;
        }
        args.add(s.substring(start, i).trim());
      }
    }
  }
  return args;
}

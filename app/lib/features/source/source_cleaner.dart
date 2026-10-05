/// 章节清洗管线（纯函数，零 Flutter 依赖）。
///
/// 语义对照 so-novel ChapterFilter + ChapterFormatter + txt 渲染，
/// 差异：落盘契约是纯文本 book.txt（段落 = 非空行），不生成 <p>：
/// 1. 隐形字符清洗（控制符/格式符/PUA——中文乱码根源，正则直搬）
/// 2. HTML 实体去除（`&[^;]+;`）
/// 3. 广告过滤：filterTxt 正则 + filterTag 选择器整段移除
/// 4. 正文开头重复标题删除；标题「1.章名」归一为「第1章 章名」
/// 5. 段落切分：闭合标签 = 块级子元素 text；未闭合 = paragraphTag 分隔后剥标签
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'source_models.dart';

/// 隐形字符正则（so-novel cleanInvisibleChars 直搬：控制符/格式符/PUA/行段落分隔符）。
final _invisibleChars = RegExp(
  r'[\p{C}\p{Cf}\p{Co}\p{Zl}\p{Zp}​﻿]',
  unicode: true,
);

final _htmlEntity = RegExp(r'&[^;]+;');
final _anyTag = RegExp(r'<[^>]+>');
final _titleNumber = RegExp(r'^(\d+)\s*\.\s*(.+)$');

/// 清洗一章：返回归一后的标题 + 段落列表（非空、已 trim）。
({String title, List<String> paragraphs}) cleanChapter(
  ChapterRule rule,
  String title,
  String rawHtml,
) {
  var content = rawHtml.replaceAll(_invisibleChars, '');
  content = content.replaceAll(_htmlEntity, '');

  // 广告文本正则（整段移除命中内容）
  final filterTxt = rule.filterTxt.trim();
  if (filterTxt.isNotEmpty) {
    try {
      content = content.replaceAll(RegExp(filterTxt), '');
    } on Object {
      // 规则自带坏正则：跳过该步，正文仍可用
    }
  }

  // 广告标签整段移除
  final filterTag = rule.filterTag.trim();
  if (filterTag.isNotEmpty) {
    content = _removeTags(content, filterTag);
  }

  // 删除正文开头的重复标题（原文/去空白两式；保留原前缀空白/标签）
  var newTitle = title.trim();
  if (newTitle.isNotEmpty) {
    final plain = newTitle.replaceAll(RegExp(r'\s+'), '');
    final esc = [newTitle, plain].map(RegExp.escape).join('|');
    // so-novel：保留前缀（空白/标签）只删标题文本——残留坏标签由空段过滤兜住
    content = content.replaceFirstMapped(
      RegExp('^(\\s|<[^>]+>)*($esc)'),
      (m) => m.group(1) ?? '',
    );
  }

  // 「1.章节名」→「第1章 章节名」（阅读器/目录都能认）
  final tm = _titleNumber.firstMatch(newTitle);
  if (tm != null) {
    newTitle = '第${tm.group(1)}章 ${tm.group(2)}';
  }

  final paragraphs = rule.paragraphTagClosed
      ? _splitByClosedTags(content)
      : _splitBySeparator(content, rule.paragraphTag);

  return (title: newTitle, paragraphs: paragraphs);
}

String _removeTags(String html, String selectorsCsv) {
  dom.DocumentFragment frag;
  try {
    frag = html_parser.parseFragment(html, container: 'div');
  } on Object {
    return html;
  }
  for (final sel in selectorsCsv.split(',')) {
    final s = sel.trim();
    if (s.isEmpty) continue;
    try {
      for (final el in frag.querySelectorAll(s).toList()) {
        el.remove();
      }
    } on Object {
      // 单个选择器无效跳过
    }
  }
  // DocumentFragment 无 innerHtml：子节点手工序列化
  return frag.nodes
      .map((n) => n is dom.Element ? n.outerHtml : (n.text ?? ''))
      .join();
}

/// 闭合标签段落：优先 <p>；无 <p> 用「最内层 div」（不含 div 子元素的）；
/// 两者皆无则剥标签按行。嵌套结构按叶子块切，粒度接近 so-novel 的
/// 「非 p 闭合标签转 <p>」效果。
List<String> _splitByClosedTags(String html) {
  dom.DocumentFragment frag;
  try {
    frag = html_parser.parseFragment(html, container: 'div');
  } on Object {
    return _stripToLines(html);
  }
  final ps = frag
      .querySelectorAll('p')
      .where((e) => e.text.trim().isNotEmpty)
      .toList();
  if (ps.isNotEmpty) {
    return ps.map((e) => e.text.trim()).toList();
  }
  final divs = frag
      .querySelectorAll('div')
      .where((e) => e.querySelector('div') == null && e.text.trim().isNotEmpty)
      .toList();
  if (divs.isNotEmpty) {
    return divs.map((e) => e.text.trim()).toList();
  }
  // 无标签裸文本
  return _stripToLines(html.replaceAll(_anyTag, ''));
}

/// 未闭合段落：按 paragraphTag 分隔（如 `<br>+`）后剥标签。
List<String> _splitBySeparator(String html, String paragraphTag) {
  var sep = paragraphTag.trim();
  if (sep.isEmpty) sep = '<br>+';
  // `<br>+` 语义：一个或多个 <br>（可能带属性/斜杠）。
  // 用户导入的规则可能带坏正则：编译失败回退默认 <br> 切分，不整书报废。
  final pattern = () {
    try {
      return RegExp(
        sep
            .replaceAll('<br>+', r'<br\s*/?>(?:\s*<br\s*/?>\s*)*')
            .replaceAll('<br>', r'<br\s*/?>'),
        caseSensitive: false,
      );
    } on Object {
      return RegExp(r'<br\s*/?>(?:\s*<br\s*/?>\s*)*', caseSensitive: false);
    }
  }();
  return html
      .split(pattern)
      .map((s) => s.replaceAll(_anyTag, '').trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

List<String> _stripToLines(String text) =>
    text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

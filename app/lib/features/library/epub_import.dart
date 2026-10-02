import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;

/// epub 导入结果：元数据 + 规范化全文 + 封面（JPEG）+ 章节表。
class EpubNovel {
  const EpubNovel({
    required this.title,
    required this.author,
    required this.text,
    this.coverJpg,
    this.publishedMonth,
    this.chapters = const [],
  });

  final String title;
  final String author;
  final String text;
  final Uint8List? coverJpg;

  /// dc:date 归一化到 YYYY-MM（没有则为 null，不要用上传时间顶替）。
  final String? publishedMonth;

  /// 章节表：标题 + 在段落序列中的起始下标。
  final List<({String title, int para})> chapters;
}

/// 解析 epub：提取书名/作者/封面，章节树转纯文本（含章节标题行）。
/// 解析失败抛 FormatException。
Future<EpubNovel> importEpub(Uint8List bytes) async {
  final EpubBook book;
  try {
    book = await EpubReader.readBook(bytes);
  } on Object catch (e) {
    throw FormatException('epub 解析失败: $e');
  }

  final buf = StringBuffer();
  final chapters = <({String title, int para})>[];
  var paraCount = 0;
  void walk(List<EpubChapter>? chaptersTree) {
    for (final c in chaptersTree ?? const <EpubChapter>[]) {
      final title = c.Title?.trim();
      final text = htmlToText(c.HtmlContent ?? '');
      final lines = text.isEmpty ? const <String>[] : text.split('\n');
      // 正文首行已与目录标题一致时不再额外插标题（避免"很多个第一章"）
      final titleInContent =
          title != null &&
          title.isNotEmpty &&
          lines.isNotEmpty &&
          _squash(lines.first) == _squash(title);
      if (title != null && title.isNotEmpty) {
        chapters.add((title: title, para: paraCount));
        if (!titleInContent) {
          buf
            ..writeln()
            ..writeln(title)
            ..writeln();
          paraCount++;
        }
      }
      if (text.isNotEmpty) {
        buf.writeln(text);
        paraCount += lines.where((e) => e.trim().isNotEmpty).length;
      }
      walk(c.SubChapters);
    }
  }

  walk(book.Chapters);
  var text = buf.toString().trim();

  // 章节树为空时按内容文件兜底（有些 epub 没有 NCX/nav）
  if (text.isEmpty) {
    final files = book.Content?.Html?.values;
    if (files != null) {
      for (final f in files) {
        final t = htmlToText(f.Content ?? '');
        if (t.isNotEmpty) buf.writeln(t);
      }
      text = buf.toString().trim();
    }
  }
  if (text.isEmpty) throw const FormatException('epub 中没有可读文本');

  Uint8List? cover;
  final coverImage = book.CoverImage;
  if (coverImage != null) {
    cover = Uint8List.fromList(img.encodeJpg(coverImage, quality: 88));
  }

  final authors = (book.AuthorList ?? [book.Author]).whereType<String>();
  final rawDate = book.Schema?.Package?.Metadata?.Dates
      ?.map((d) => d.Date)
      .whereType<String>()
      .firstOrNull;
  return EpubNovel(
    title: book.Title?.trim() ?? '',
    author: authors.join(' / '),
    text: text,
    coverJpg: cover,
    publishedMonth: _monthOf(rawDate),
    chapters: chapters,
  );
}

/// '2021-05' / '2021/5/3' / '20210503' → 'YYYY-MM'；拿不到返回 null。
String? _monthOf(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'(\d{4})[-/.]?(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return null;
  return '${m.group(1)}-${m.group(2)}';
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

/// HTML → 纯文本：去脚本/样式/标签，常见实体解码，空白归一（纯函数，单测对象）。
String htmlToText(String html) {
  var s = html;
  s = s.replaceAll(
    RegExp('<head[^>]*>[\\s\\S]*?</head>', caseSensitive: false),
    ' ',
  );
  s = s.replaceAll(
    RegExp('<(script|style)[^>]*>[\\s\\S]*?</\\1>', caseSensitive: false),
    ' ',
  );
  s = s.replaceAll(RegExp('<br\\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(
    RegExp('</(p|div|h[1-6]|li|tr)>', caseSensitive: false),
    '\n',
  );
  s = s.replaceAll(RegExp('<[^>]+>'), '');
  s = _decodeEntities(s);
  s = s
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp('[ \\t 　]+'), ' ')
      .replaceAll(RegExp('\\n{3,}'), '\n\n');
  return s.trim();
}

String _decodeEntities(String s) {
  const map = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&nbsp;': ' ',
  };
  var out = s;
  for (final e in map.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  out = out.replaceAllMapped(
    RegExp('&#(\\d+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!)),
  );
  out = out.replaceAllMapped(
    RegExp('&#x([0-9a-fA-F]+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
  );
  return out;
}

/// 下载产物拼合（纯函数，零 Flutter 依赖）：staging 章 → book.txt +
/// chapters.json + meta.json（设计文档 §4.2，meta 含 source 回溯块供 M6 追更）。
library;

import 'dart:convert';

/// 一章的清洗后形态。
class ChapterDraft {
  const ChapterDraft(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

/// 拼合结果。
class AssembledBook {
  const AssembledBook({
    required this.bookTxt,
    required this.chaptersJson,
    required this.metaJson,
    required this.totalChars,
  });

  /// UTF-8 纯文本；段落=非空行，章标题行内嵌（阅读器 splitParagraphs 契约）。
  final String bookTxt;

  /// `[{"title":…,"para":…}]`（para = 章标题行在段落序列中的下标）。
  final String chaptersJson;

  /// §4.2 meta.json。
  final String metaJson;

  final int totalChars;
}

/// 拼合全书。[today] 格式 YYYY-MM-DD。
AssembledBook assembleBook({
  required String workId,
  required List<ChapterDraft> chapters,
  required String bookName,
  required String author,
  required String status,
  required String sourceId,
  required String bookUrl,
  required String today,
  List<String> tags = const [],
}) {
  final lines = <String>[];
  final chapterTable = <Map<String, Object?>>[];
  final metaChapters = <Map<String, Object?>>[];
  var para = 0; // 已写入的非空行数（= splitParagraphs 下标）
  var byteOffset = 0;
  var totalChars = 0;

  var idx = 0;
  for (final ch in chapters) {
    final title = ch.title.trim();
    if (title.isEmpty) continue;
    idx++;
    final firstPara = ch.paragraphs.isNotEmpty
        ? ch.paragraphs.first.trim()
        : '';
    chapterTable.add({'title': title, 'para': para});
    final chapterStart = byteOffset;
    var chars = 0; // 只计实际写入的行（标题去重时不重复计）
    if (firstPara != title) {
      lines.add(title);
      para++;
      byteOffset += utf8.encode('$title\n').length;
      chars += title.length;
    }
    for (final p in ch.paragraphs) {
      final t = p.trim();
      if (t.isEmpty) continue;
      lines.add(t);
      para++;
      byteOffset += utf8.encode('$t\n').length;
      chars += t.length;
    }
    totalChars += chars;
    metaChapters.add({
      'i': idx - 1,
      'title': title,
      'para': chapterTable.last['para'],
      'offset': chapterStart,
      'chars': chars,
    });
  }

  final bookTxt = lines.isEmpty ? '' : '${lines.join('\n')}\n';
  final meta = <String, Object?>{
    'id': workId,
    'title': bookName,
    'author': author,
    'series': '',
    'status': status,
    'total_chars': totalChars,
    'last_updated': today,
    'source': {
      'source_id': sourceId,
      'book_url': bookUrl,
      'last_synced_chapter': idx,
    },
    'volumes': [
      {'v': 1, 'title': '', 'chapters': metaChapters},
    ],
    if (tags.isNotEmpty) 'tags': tags,
  };
  return AssembledBook(
    bookTxt: bookTxt,
    chaptersJson: jsonEncode(chapterTable),
    metaJson: const JsonEncoder.withIndent('  ').convert(meta),
    totalChars: totalChars,
  );
}

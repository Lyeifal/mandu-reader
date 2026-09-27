import 'dart:convert';

/// works.jsonl 单行（设计文档 §4.1）。解析器容忍缺省字段，
/// 仅 id/type/title 为必需。
class WorksIndexEntry {
  const WorksIndexEntry({
    required this.id,
    required this.type,
    required this.title,
    this.titleJp = '',
    this.author = '',
    this.series = '',
    this.volume,
    this.tags = const [],
    this.status = 'ongoing',
    this.totalChars,
    this.pages,
    this.lastUpdated,
    this.cover,
    this.origin = 'manual',
    this.localOnly = false,
  });

  final String id;
  final String type; // novel | manga
  final String title;
  final String titleJp;
  final String author;
  final String series;
  final int? volume;
  final List<String> tags;
  final String status;
  final int? totalChars;
  final int? pages;
  final String? lastUpdated;
  final String? cover;
  final String origin;
  final bool localOnly;

  factory WorksIndexEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final title = json['title'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('缺少 id');
    }
    if (type is! String || (type != 'novel' && type != 'manga')) {
      throw FormatException('type 必须是 novel|manga: $type');
    }
    if (title is! String || title.isEmpty) {
      throw const FormatException('缺少 title');
    }
    return WorksIndexEntry(
      id: id,
      type: type,
      title: title,
      titleJp: (json['title_jp'] ?? '') as String,
      author: (json['author'] ?? '') as String,
      series: (json['series'] ?? '') as String,
      volume: json['volume'] as int?,
      tags: ((json['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      status: (json['status'] ?? 'ongoing') as String,
      totalChars: json['total_chars'] as int?,
      pages: json['pages'] as int?,
      lastUpdated: json['last_updated'] as String?,
      cover: json['cover'] as String?,
      origin: (json['origin'] ?? 'manual') as String,
      localOnly: (json['local_only'] as bool?) ?? false,
    );
  }
}

/// 坏行记录（设计文档 §5.2：跳坏行并记录）。
class BadLine {
  const BadLine(this.lineNo, this.raw, this.error);

  final int lineNo;
  final String raw;
  final String error;

  @override
  String toString() => 'L$lineNo: $error';
}

class WorksIndexParseResult {
  const WorksIndexParseResult(this.entries, this.badLines);

  final List<WorksIndexEntry> entries;
  final List<BadLine> badLines;
}

/// 逐行解析 works.jsonl：空行跳过，坏行收集，不抛异常（§5.2）。
WorksIndexParseResult parseWorksIndex(String content) {
  final entries = <WorksIndexEntry>[];
  final badLines = <BadLine>[];
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) continue;
    try {
      entries.add(
        WorksIndexEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
    } on Object catch (e) {
      badLines.add(BadLine(i + 1, raw, e.toString()));
    }
  }
  return WorksIndexParseResult(entries, badLines);
}

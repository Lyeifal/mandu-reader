import 'dart:convert';

/// JM 相册元数据（jm_driver.py 的 META 行）。
class JmAlbumMeta {
  const JmAlbumMeta({
    required this.albumId,
    required this.title,
    required this.authors,
    required this.tags,
    required this.works,
    this.pubDate = '',
    this.updateDate = '',
    this.pageCount = 0,
  });

  final String albumId;
  final String title;
  final List<String> authors;
  final List<String> tags;

  /// JM「作品」字段，作为系列名。
  final List<String> works;
  final String pubDate;
  final String updateDate;
  final int pageCount;

  factory JmAlbumMeta.fromJson(Map<String, dynamic> json) => JmAlbumMeta(
    albumId: (json['album_id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    authors: _strList(json['authors']),
    tags: _strList(json['tags']),
    works: _strList(json['works']),
    pubDate: (json['pub_date'] ?? '').toString(),
    updateDate: (json['update_date'] ?? '').toString(),
    pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
  );

  static List<String> _strList(Object? v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  String get author => authors.join(' / ');

  String get series => works.join(' / ');
}

/// 驱动进程的一行输出。
sealed class JmDriverLine {
  const JmDriverLine();
}

class JmMetaLine extends JmDriverLine {
  const JmMetaLine(this.meta);
  final JmAlbumMeta meta;
}

class JmFilesLine extends JmDriverLine {
  const JmFilesLine(this.files);
  final List<String> files;
}

class JmDoneLine extends JmDriverLine {
  const JmDoneLine();
}

class JmErrorLine extends JmDriverLine {
  const JmErrorLine(this.message);
  final String message;
}

/// 解析驱动输出的一行；非协议行（jmcomic 日志等）返回 null。
JmDriverLine? parseJmDriverLine(String line) {
  final l = line.trimRight();
  if (l.startsWith('META ')) {
    final json = jsonDecode(l.substring(5)) as Map<String, dynamic>;
    return JmMetaLine(JmAlbumMeta.fromJson(json));
  }
  if (l.startsWith('FILES ')) {
    final json = jsonDecode(l.substring(6));
    return JmFilesLine(
      json is List ? json.map((e) => e.toString()).toList() : const [],
    );
  }
  if (l == 'DONE') return const JmDoneLine();
  if (l.startsWith('ERROR ')) return JmErrorLine(l.substring(6));
  return null;
}

/// 从用户输入解析 JM 相册 ID：支持纯数字或任意含数字的 URL/文本。
String? parseJmAlbumId(String input) {
  final m = RegExp(r'(\d{4,})').firstMatch(input);
  return m?.group(1);
}

/// 'YYYY-MM-DD' / 'YYYY/MM/DD' → 'YYYY-MM'（时间筛选粒度）；非法输入返回 null。
String? jmMonth(String raw) {
  final m = RegExp(r'(\d{4})[-/](\d{2})').firstMatch(raw);
  if (m == null) return null;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return null;
  return '${m.group(1)}-${m.group(2)}';
}

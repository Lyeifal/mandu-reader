/// 桶内 key 路径构造与解析（设计文档 §3）。
/// 纯函数，无 IO —— 本文件是单测重点对象。
class LibraryPaths {
  LibraryPaths._();

  static const root = 'library';
  static const indexPrefix = '$root/_index/';
  static const statePrefix = '$root/_state/';
  static const fontsPrefix = '$root/_fonts/';
  static const worksIndex = '${indexPrefix}works.jsonl';
  static const eventsLog = '${statePrefix}events.jsonl';

  static const _illegal = <String>[
    '/',
    '\\',
    ':',
    '*',
    '?',
    '"',
    '<',
    '>',
    '|',
  ];

  /// 清洗单段路径名：去掉文件系统非法字符与控制字符、首尾空白与前导点，
  /// 长度截到 80；空结果与点段回退 `unnamed`。保留内部点（文件名扩展名需要）。
  static String sanitizeSegment(String raw) {
    final buf = StringBuffer();
    for (final ch in raw.trim().codeUnits) {
      final c = String.fromCharCode(ch);
      if (ch < 0x20 || _illegal.contains(c)) continue;
      buf.write(c);
    }
    var s = buf.toString().trim();
    while (s.startsWith('.')) {
      s = s.substring(1);
    }
    if (s.length > 80) s = s.substring(0, 80).trim();
    if (s.isEmpty || s == '.' || s == '..') return 'unnamed';
    return s;
  }

  /// 小说目录：`library/小说/<作者>/<系列>/<书名>/`（系列可空）。
  static String novelDir({
    required String author,
    String series = '',
    required String title,
  }) {
    final segs = ['小说', sanitizeSegment(author)];
    final s = sanitizeSegment(series);
    if (s != 'unnamed') segs.add(s);
    segs.add(sanitizeSegment(title));
    return '$root/${segs.join('/')}';
  }

  static String novelTxt({
    required String author,
    String series = '',
    required String title,
  }) => '${novelDir(author: author, series: series, title: title)}/book.txt';
  static String novelEpub({
    required String author,
    String series = '',
    required String title,
  }) => '${novelDir(author: author, series: series, title: title)}/book.epub';
  static String novelMeta({
    required String author,
    String series = '',
    required String title,
  }) => '${novelDir(author: author, series: series, title: title)}/meta.json';
  static String novelCover({
    required String author,
    String series = '',
    required String title,
  }) => '${novelDir(author: author, series: series, title: title)}/cover.avif';

  /// 漫画目录：`library/漫画/<作者>/<系列>/<卷>/`（系列可空，卷三位补零）。
  static String mangaDir({
    required String author,
    String series = '',
    required String title,
    required int volume,
  }) {
    final segs = ['漫画', sanitizeSegment(author)];
    final s = sanitizeSegment(series);
    if (s != 'unnamed') segs.add(s);
    segs
      ..add(sanitizeSegment(title))
      ..add('v${volume.toString().padLeft(3, '0')}');
    return '$root/${segs.join('/')}';
  }

  static String mangaPage(String dir, int page, {String ext = 'avif'}) =>
      '$dir/${page.toString().padLeft(3, '0')}.$ext';

  static String mangaMeta({
    required String author,
    String series = '',
    required String title,
    required int volume,
  }) =>
      '${mangaDir(author: author, series: series, title: title, volume: volume)}/meta.json';

  static String fontFile(String filename) =>
      '$fontsPrefix${sanitizeSegment(filename)}';
}

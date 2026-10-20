part of 'reader_page.dart';

// 纯函数 + 主题 + 数字输入 + 数据 providers（自 reader_page.dart 拆出，行为不变）。

/// 漫画页源：本地目录文件，或桶内目录的预签名 URL 列表。
final _pageSourcesProvider = FutureProvider.family<List<String>, Work>((
  ref,
  work,
) async {
  if (work.localOnly) {
    final root = await resolveLocalRoot(ref.read(settingsRepositoryProvider));
    final dir = Directory(p.join(root, work.id));
    if (!await dir.exists()) throw StateError('本地目录不存在');
    const exts = {'.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif', '.bmp'};
    final files = await dir
        .list()
        .where(
          (e) => e is File && exts.contains(p.extension(e.path).toLowerCase()),
        )
        .map((e) => e.path)
        .toList();
    files.sort();
    if (files.isEmpty) throw StateError('本地目录里没有图片文件');
    return files;
  }
  final client = ref.read(bucketClientProvider);
  if (client == null) throw StateError('桶客户端不可用');
  final cover = work.cover;
  if (cover == null || cover.isEmpty) {
    throw StateError('缺少 cover 字段，无法定位页面目录');
  }
  // cover 可能不带 library/ 前缀（设计文档 §4.1 示例），读取侧归一
  final dir = p.dirname(LibraryPaths.normalizeKey(cover));
  final keys = await client.listKeys(dir, max: 1000);
  final pages =
      keys.where((k) => RegExp(r'/(\d{3,5})\.\w+$').hasMatch(k)).toList()
        ..sort();
  if (pages.isEmpty) throw StateError('桶里没找到页面');
  const ttl = Duration(hours: 1);
  return [for (final k in pages) await client.presignGet(k, ttl: ttl)];
});

/// 数字输入框：回车提交（页码 / 秒数 / 百分比共用）。
class _NumberInput extends StatefulWidget {
  const _NumberInput({required this.hintText, required this.onSubmit});

  final String hintText;
  final ValueChanged<int> onSubmit;

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      onSubmitted: (v) {
        final n = int.tryParse(v.trim());
        if (n != null) {
          widget.onSubmit(n);
          _controller.clear();
        }
      },
    );
  }
}

/// 主题预设（设计文档 §阅读器主题）：背景色 + 文字色。
class _NovelTheme {
  const _NovelTheme(this.bg, this.fg);

  final Color bg;
  final Color fg;

  static const presets = {
    'day': _NovelTheme(Color(0xFFFCFCFA), Color(0xFF2A2A2A)),
    'eyecare': _NovelTheme(Color(0xFFC7EDCC), Color(0xFF3A4A3C)),
    'parchment': _NovelTheme(Color(0xFFF5F0E1), Color(0xFF4A4234)),
    'night': _NovelTheme(Color(0xFF111318), Color(0xFFB8BDC7)),
  };
}

/// 全文 → 段落序列（非空行，稳定切分供书签/章节定位）。
List<String> splitParagraphs(String text) =>
    text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/// 连续重复段落去重：早期导入的 epub 文本每章标题会重复 2~3 次，
/// 折叠后与新版导入效果一致（书签/章节定位都基于去重后的序列）。
List<String> dedupeConsecutive(List<String> paragraphs) {
  final out = <String>[];
  for (final p in paragraphs) {
    if (out.isEmpty || out.last != p) out.add(p);
  }
  return out;
}

/// 阅读器统一入口：切分 + 去重。
List<String> novelParagraphs(String text) =>
    dedupeConsecutive(splitParagraphs(text));

/// 分页结果：每页文本行 + 每页起始段落下标（章节/书签跳转用）+
/// 每页内「章标题行」的下标集合（章标题加粗放大渲染用）。
class NovelPages {
  const NovelPages(this.pages, this.startParas, [this.titleMasks = const []]);

  final List<List<String>> pages;
  final List<int> startParas;

  /// 与 pages 对齐：页内哪些行是章标题（段落下标在 chapterStarts 里的段的首行）。
  final List<Set<int>> titleMasks;

  int get length => pages.length;

  /// 段落所在页（最后一个 startPara <= para 的页）。
  int pageOfPara(int para) {
    var lo = 0, hi = startParas.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (startParas[mid] <= para) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}

double _charUnits(int rune) => rune < 128 ? 0.55 : 1.0;

/// 按行宽（字数容量）把一段文本折成多行（纯函数）。
List<String> wrapText(String text, double capacityUnits) {
  final lines = <String>[];
  final cur = StringBuffer();
  var units = 0.0;
  for (final rune in text.runes) {
    final u = _charUnits(rune);
    if (units + u > capacityUnits && cur.isNotEmpty) {
      lines.add(cur.toString());
      cur.clear();
      units = 0;
    }
    cur.writeCharCode(rune);
    units += u;
  }
  if (cur.isNotEmpty) lines.add(cur.toString());
  return lines;
}

/// 真实分页：每行容量 = 内容宽/字号（中文≈1 字宽，ASCII≈0.55），
/// 每页行数 = 内容高/(字号×行高+行距)；超长段落跨页切断，内容不丢（纯函数）。
/// [widthFactor] 收紧行容量（<1），用于自定义字体等「字宽启发式不精确」场景留安全边。
/// [chapterStarts] 章起始段落下标（chapters.json/deriveChapters 的 para 集合）：
/// 商业阅读器行为——新章**强制另起新页**，章标题不跟在上一章尾行后面；
/// 首行渲染为标题样式（字号不变，行高收紧以匹配行预算，见 titleMasks）。
NovelPages paginateNovel(
  List<String> paragraphs, {
  required double contentWidth,
  required double contentHeight,
  required int fontSize,
  double lineHeight = 1.7,
  double lineSpacing = 2,
  double widthFactor = 1.0,
  Set<int> chapterStarts = const {},
}) {
  final capacityUnits = contentWidth / fontSize * widthFactor;
  // 行渲染成本 = 行高 + 行距（Padding），必须与实际渲染一致，否则溢出
  final lineCost = fontSize * lineHeight + lineSpacing;
  final linesPerPage = (contentHeight / lineCost).floor().clamp(1, 1 << 20);

  final pages = <List<String>>[];
  final starts = <int>[];
  final masks = <Set<int>>[];
  var current = <String>[];
  var currentMask = <int>{};
  var budget = linesPerPage;
  var startPara = 0;

  void flush() {
    if (current.isEmpty) return;
    pages.add(current);
    starts.add(startPara);
    masks.add(currentMask);
    current = [];
    currentMask = {};
    budget = linesPerPage;
  }

  for (var pi = 0; pi < paragraphs.length; pi++) {
    if (current.isEmpty) startPara = pi;
    final lines = wrapText(paragraphs[pi], capacityUnits);
    var idx = 0;
    // 新章另起新页：上一章尾页不满也合上（首页无内容时不触发）
    final isChapterStart = chapterStarts.contains(pi);
    if (isChapterStart && current.isNotEmpty) {
      flush();
      startPara = pi;
    }
    while (idx < lines.length) {
      if (budget <= 0) {
        flush();
        startPara = pi; // 新页从当前段开始
      }
      final take = budget < lines.length - idx ? budget : lines.length - idx;
      if (isChapterStart && idx == 0) currentMask.add(current.length);
      current.addAll(lines.sublist(idx, idx + take));
      idx += take;
      budget -= take;
    }
  }
  flush();
  if (pages.isEmpty) pages.add(const []);
  return NovelPages(pages, starts, masks);
}

/// 无 chapters.json 时按「第X章/节/卷/回」标题行推导章节表（纯函数）。
List<({String title, int para})> deriveChapters(List<String> paragraphs) {
  final re = RegExp(r'^第.{1,15}[章节卷回]');
  final out = <({String title, int para})>[];
  for (var i = 0; i < paragraphs.length; i++) {
    final line = paragraphs[i];
    if (line.length <= 40 && re.hasMatch(line)) {
      out.add((title: line, para: i));
    }
  }
  return out;
}

/// 书内搜索命中（纯数据）。坐标用段落号，与书签/进度/章节同一坐标系。
class SearchHit {
  const SearchHit(this.para, this.offset, this.excerpt, this.excerptHitAt);

  final int para; // 段落号
  final int offset; // 段内命中起点（lower 索引，见 searchNovel 注）
  final String excerpt; // 命中前后各 [contextRadius] 字符的摘录（越界加省略号）
  final int excerptHitAt; // 命中起点在 excerpt 中的下标（UI 高亮用）
}

/// 书内搜索：大小写不敏感子串扫描，逐段命中、段内与总量双封顶（纯函数）。
/// 命中位置在 lower 串上计算——土耳其式 İ 等 toLowerCase 变长特例会让
/// 索引对原串轻微错位，中文/ASCII 场景长度不变、无影响。
List<SearchHit> searchNovel(
  List<String> paragraphs,
  String query, {
  int maxPerPara = 3,
  int maxTotal = 300,
  int contextRadius = 24,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final hits = <SearchHit>[];
  outer:
  for (var pi = 0; pi < paragraphs.length; pi++) {
    final para = paragraphs[pi];
    final lower = para.toLowerCase();
    var from = 0;
    var perPara = 0;
    while (true) {
      final at = lower.indexOf(q, from);
      if (at < 0) break;
      final start = (at - contextRadius).clamp(0, para.length);
      final end = (at + q.length + contextRadius).clamp(0, para.length);
      final leadIn = at - start; // 命中词前残留的字符数（在原文坐标里）
      final hasPrefix = start > 0;
      final hasSuffix = end < para.length;
      hits.add(
        SearchHit(
          pi,
          at,
          '${hasPrefix ? '…' : ''}${para.substring(start, end)}'
          '${hasSuffix ? '…' : ''}',
          (hasPrefix ? 1 : 0) + leadIn,
        ),
      );
      perPara++;
      if (perPara >= maxPerPara) break;
      from = at + q.length;
      if (hits.length >= maxTotal) break outer;
    }
  }
  return hits;
}

/// 解析 'HH:mm' 为当日分钟数（0~1439）；非法返回 null（纯函数）。
int? parseHm(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// 分钟级时间窗口判定，支持跨零点（如 20:00–07:00）（纯函数）。
bool inNightWindow(int startMin, int endMin, int nowMin) => startMin <= endMin
    ? (startMin <= nowMin && nowMin < endMin)
    : (nowMin >= startMin || nowMin < endMin);

/// 定时切换评估：返回应切换到的预设 key；null = 不覆盖手动选择（纯函数）。
/// [mode]：off | system（跟随系统深色）| time（按时段）。
String? evaluateThemeSchedule(
  String mode,
  String nightPreset,
  String startHm,
  String endHm,
  int nowMin,
  bool systemDark,
) {
  switch (mode) {
    case 'system':
      return systemDark ? nightPreset : null;
    case 'time':
      final s = parseHm(startHm);
      final e = parseHm(endHm);
      if (s == null || e == null) return null;
      return inNightWindow(s, e, nowMin) ? nightPreset : null;
    default:
      return null;
  }
}

/// 解析 '#RRGGBB'（容忍无前导 #、任意大小写）；非法返回 null（纯函数）。
Color? parseHexColor(String s) {
  var t = s.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (t.length != 6) return null;
  final v = int.tryParse(t, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

/// Color → '#RRGGBB'（纯函数；走 r/g/b 通道，避开 Color.value 的版本差异）。
String formatHexColor(Color c) {
  String h(double v) =>
      (v * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

/// 字体文件 → fontFamily 名（纯函数）：user_ + 基名去扩展名，
/// 非 [A-Za-z0-9_-] 一律换 _，空基名回退 'font'。family 名自定义，
/// 无需解析字体内部的名称表。
String fontFamilyFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  final clean = stem.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return 'user_${clean.isEmpty ? 'font' : clean}';
}

/// 漫画双页对开的一个 spread（纯数据）。
typedef Spread = ({int first, int len});

/// 横图判定（跨页横图，应独占一个 spread）：宽高比 ≥ 阈值（纯函数）。
bool isWideImage(Size size, {double threshold = 1.4}) =>
    size.height > 0 && size.width / size.height >= threshold;

/// 双页对开分页（纯函数）：已确认横图独占一页，其余乐观两两配对。
/// 未探测页按非横图处理——探测结果回流后重算并锚定「当前首页面码」。
List<Spread> computeSpreads(int total, Set<int> widePages) {
  final out = <Spread>[];
  var i = 0;
  while (i < total) {
    if (widePages.contains(i)) {
      out.add((first: i, len: 1));
      i++;
    } else if (i + 1 < total && !widePages.contains(i + 1)) {
      out.add((first: i, len: 2));
      i += 2;
    } else {
      out.add((first: i, len: 1));
      i++;
    }
  }
  return out;
}

/// 页码（0 基）→ 所在 spread 下标（纯函数）；越界夹到首/尾。
int spreadIndexForPage(List<Spread> spreads, int page) {
  if (spreads.isEmpty) return 0;
  for (var i = 0; i < spreads.length; i++) {
    if (spreads[i].first + spreads[i].len > page) return i;
  }
  return spreads.length - 1;
}

/// 小说书签（works 表的书签流）。
final _bookmarksProvider = StreamProvider.family<List<Bookmark>, String>((
  ref,
  workId,
) {
  final db = ref.watch(appDatabaseProvider);
  final q = db.select(db.bookmarks)
    ..where((t) => t.workId.equals(workId))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
  return q.watch();
});

final _novelTextProvider = FutureProvider.family<String, Work>((
  ref,
  work,
) async {
  if (work.localOnly) {
    final root = await resolveLocalRoot(ref.read(settingsRepositoryProvider));
    final f = File(p.join(root, work.id, 'book.txt'));
    if (!await f.exists()) throw StateError('本地没有 book.txt');
    return f.readAsString();
  }
  final client = ref.read(bucketClientProvider);
  if (client == null) throw StateError('桶客户端不可用');
  final cover = work.cover;
  final dir = cover != null && cover.isNotEmpty
      ? p.dirname(
          // cover 可能不带 library/ 前缀（设计文档 §4.1 示例），读取侧归一
          LibraryPaths.normalizeKey(cover),
        )
      : LibraryPaths.novelDir(
          author: work.author,
          series: work.series,
          title: work.title,
        );
  // 本地缓存优先：首次下载落盘，之后秒开且离线可读
  final cache = await _novelCacheFile(ref, work.id, 'book.txt');
  if (await cache.exists()) {
    return utf8.decode(await cache.readAsBytes(), allowMalformed: true);
  }
  final bytes = await client.getAll('$dir/book.txt');
  try {
    await cache.parent.create(recursive: true);
    await cache.writeAsBytes(bytes);
  } on Object {
    // 缓存写失败不影响阅读
  }
  return utf8.decode(bytes, allowMalformed: true);
});

/// 云端小说附属文件（book.txt / chapters.json）的本地缓存位置。
Future<File> _novelCacheFile(Ref ref, String workId, String name) async {
  final root = await resolveLocalRoot(ref.read(settingsRepositoryProvider));
  return File(p.join(root, '_novel_cache', workId, name));
}

/// 章节表（导入 epub 时落盘的 chapters.json）；没有则返回 null，阅读器用正则推导。
final _chaptersFileProvider =
    FutureProvider.family<List<({String title, int para})>?, Work>((
      ref,
      work,
    ) async {
      String? raw;
      if (work.localOnly) {
        final root = await resolveLocalRoot(
          ref.read(settingsRepositoryProvider),
        );
        final f = File(p.join(root, work.id, 'chapters.json'));
        if (!await f.exists()) return null;
        raw = await f.readAsString();
      } else {
        final client = ref.read(bucketClientProvider);
        final cover = work.cover;
        if (client == null || cover == null || cover.isEmpty) return null;
        try {
          final cache = await _novelCacheFile(ref, work.id, 'chapters.json');
          final Uint8List bytes;
          if (await cache.exists()) {
            bytes = await cache.readAsBytes();
          } else {
            bytes = await client.getAll(
              '${p.dirname(LibraryPaths.normalizeKey(cover))}/chapters.json',
            );
            try {
              await cache.parent.create(recursive: true);
              await cache.writeAsBytes(bytes);
            } on Object {
              // 缓存写失败不影响阅读
            }
          }
          raw = utf8.decode(bytes, allowMalformed: true);
        } on Object {
          return null;
        }
      }
      try {
        final list = jsonDecode(raw) as List;
        return [
          for (final e in list)
            (
              title: (e['title'] ?? '').toString(),
              para: (e['para'] as num).toInt(),
            ),
        ];
      } on Object {
        return null;
      }
    });

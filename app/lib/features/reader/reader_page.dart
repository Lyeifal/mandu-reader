import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/db/app_database.dart';
import '../bucket/path_helper.dart';
import '../downloader/display_image.dart';
import '../downloader/jm_pipeline.dart';
import '../library/events_log.dart';
import '../providers.dart';

/// 阅读器：漫画沉浸式（中央点按呼出设置，两侧点按翻页）+ 小说文本滚动。
class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return work.type == 'manga'
        ? Scaffold(
            backgroundColor: Colors.black,
            body: _MangaReader(work: work),
          )
        : _NovelReader(work: work);
  }
}

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
      keys.where((k) => RegExp(r'/(\d{3})\.\w+$').hasMatch(k)).toList()..sort();
  if (pages.isEmpty) throw StateError('桶里没找到页面');
  const ttl = Duration(hours: 1);
  return [for (final k in pages) await client.presignGet(k, ttl: ttl)];
});

/// 漫画阅读器。
///
/// 手势约定（干净优先）：
/// - 中央 50% 区域点按 → 呼出/收起设置菜单
/// - 左右各 25% 边缘点按 → 上一页 / 下一页（连续滚动模式为上下翻屏）
/// - 其余滚动/滑动行为不受点按区影响
class _MangaReader extends ConsumerStatefulWidget {
  const _MangaReader({required this.work});

  final Work work;

  @override
  ConsumerState<_MangaReader> createState() => _MangaReaderState();
}

class _MangaReaderState extends ConsumerState<_MangaReader> {
  String _mode = 'vertical'; // vertical | horizontal
  bool _snap = false; // 纵向：true=逐页，false=连续滚动
  bool _menu = false;
  int _current = 0;

  // 滚动模式全局同步缩放：双指缩放任意一页时全部页保持同一比例，
  // 页与页交界不会因只放大一页而错开。
  final Map<int, TransformationController> _zoomControllers = {};
  double _zoom = 1;

  TransformationController _zoomControllerFor(int index) =>
      _zoomControllers.putIfAbsent(index, TransformationController.new);

  void _syncZoom(int sourceIndex) {
    final s = (_zoomControllers[sourceIndex]?.value.getMaxScaleOnAxis() ?? 1.0)
        .clamp(1.0, 4.0);
    if (s == _zoom) return;
    setState(() => _zoom = s);
    for (final e in _zoomControllers.entries) {
      if (e.key != sourceIndex) {
        e.value.value = Matrix4.diagonal3Values(s, s, 1);
      }
    }
  }

  void _endZoom(int sourceIndex) {
    final s = _zoomControllers[sourceIndex]?.value.getMaxScaleOnAxis() ?? 1.0;
    if (s <= 1.02) {
      _resetZoom();
    }
  }

  void _resetZoom() {
    setState(() => _zoom = 1);
    for (final c in _zoomControllers.values) {
      c.value = Matrix4.identity();
    }
  }

  /// 放大状态下点按先退出缩放（返回 true 表示本次点按被消费）。
  bool _consumeTapIfZoomed() {
    if (_zoom <= 1.02) return false;
    _resetZoom();
    return true;
  }

  int _total = 0;
  double _scrollProgress = 0; // 连续滚动模式的进度（0 ~ total-1）
  int _autoSeconds = 5; // 自动翻页/滚动间隔，0 = 关
  int _scrollPercent = 92; // 连续滚动一次跳转的距离（可视高度百分比）

  // 进度持久化：进阅读器恢复上次位置；页变化落本地（防抖），退出写事件
  bool _progressRestored = false;
  String _devName = 'dev';
  int _lastPersistedPage = 0;

  Timer? _autoTimer;
  late final PageController _page = PageController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _scroll.addListener(_onScrollProgress);
    _resolveDevName();
  }

  Future<void> _resolveDevName() async {
    _devName = await resolveDeviceName(ref.read(settingsRepositoryProvider));
  }

  void _onScrollProgress() {
    if (_isPageMode || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0 || _total <= 1) return;
    setState(
      () => _scrollProgress = (_scroll.offset / max * (_total - 1)).clamp(
        0.0,
        _total - 1.0,
      ),
    );
    // 滚动模式按整页变化落本地（每帧都写 SQLite 没必要）
    _persistProgressLocal(_scrollProgress.round() + 1);
  }

  /// 恢复上次阅读位置（首次页面就绪后调用一次）。
  Future<void> _restoreProgress() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final row = await (db.select(
        db.readingProgress,
      )..where((t) => t.workId.equals(widget.work.id))).getSingleOrNull();
      if (row == null || !mounted) return;
      final loc = jsonDecode(row.loc);
      if (loc is Map && loc['page'] is num) {
        _jumpToPage((loc['page'] as num).toInt());
      }
    } on Object {
      // 没有/坏掉的进度记录就从第一页开始
    }
  }

  /// 页码落本地（调用方按页/整页变化节流）。
  Future<void> _persistProgressLocal(int page) async {
    if (page == _lastPersistedPage) return;
    _lastPersistedPage = page;
    try {
      await saveProgressLocal(ref.read(appDatabaseProvider), widget.work.id, {
        'page': page,
      });
    } on Object {
      // 本地失败不阻塞阅读
    }
  }

  Future<void> _loadPrefs() async {
    final repo = ref.read(settingsRepositoryProvider);
    final mode = await repo.get('reader.manga.mode');
    final snap = await repo.get('reader.manga.snap');
    final auto = int.tryParse(
      await repo.get('reader.manga.autoPageIntervalSeconds') ?? '5',
    );
    final scrollPercent = int.tryParse(
      await repo.get('reader.manga.scrollPercent') ?? '92',
    );
    if (mounted) {
      setState(() {
        if (mode == 'horizontal') _mode = 'horizontal';
        if (mode == 'vertical') _mode = 'vertical';
        _snap = snap == 'true';
        _autoSeconds = auto ?? 5;
        _scrollPercent = (scrollPercent ?? 92).clamp(10, 100);
      });
      _restartAuto();
    }
  }

  // ------------------------------------------------------------ 自动翻页

  Future<void> _savePref(String key, String value) =>
      ref.read(settingsRepositoryProvider).set(key, value);

  void _setAuto(int seconds) {
    setState(() => _autoSeconds = seconds);
    _savePref('reader.manga.autoPageIntervalSeconds', '$seconds');
    _restartAuto();
  }

  void _restartAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
    if (_autoSeconds <= 0) return;
    _autoTimer = Timer.periodic(Duration(seconds: _autoSeconds), (_) {
      _autoStep();
    });
  }

  void _autoStep() {
    if (_isPageMode) {
      if (_current >= _total - 1) {
        _setAuto(0);
        return;
      }
      _page.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      if (!_scroll.hasClients) return;
      if (_scroll.offset >= _scroll.position.maxScrollExtent - 1) {
        _setAuto(0);
        return;
      }
      _jumpScroll(1);
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    // 退出保存最终位置：本地落库 + 尽力推桶事件（失败只记日志）
    unawaited(
      saveProgressSafely(ref, widget.work, {
        'page': _isPageMode ? _current + 1 : _scrollProgress.round() + 1,
      }, dev: _devName),
    );
    _page.dispose();
    _scroll.dispose();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isPageMode => _mode == 'horizontal' || _snap;

  void _prev() {
    if (_consumeTapIfZoomed()) return;
    if (_isPageMode) {
      _page.previousPage(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      _jumpScroll(-1);
    }
  }

  void _next() {
    if (_consumeTapIfZoomed()) return;
    if (_isPageMode) {
      _page.nextPage(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      _jumpScroll(1);
    }
  }

  void _jumpScroll(int direction) {
    if (!_scroll.hasClients) return;
    final step =
        _scroll.position.viewportDimension * _scrollPercent / 100 * direction;
    final target = _scroll.offset + step;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// 跳转到指定页（1 基）。
  void _jumpToPage(int page) {
    if (_total <= 0) return;
    final target = page.clamp(1, _total);
    if (_isPageMode) {
      _page.jumpToPage(target - 1);
    } else if (_scroll.hasClients) {
      final max = _scroll.position.maxScrollExtent;
      _scroll.animateTo(
        _total > 1 ? max * (target - 1) / (_total - 1) : 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    setState(() {
      _current = target - 1;
      _scrollProgress = (target - 1).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(_pageSourcesProvider(widget.work));
    return pages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (sources) {
        if (sources.isEmpty) return const Center(child: Text('没有页面'));
        _total = sources.length;
        if (_current >= _total) _current = _total - 1;
        if (!_progressRestored) {
          _progressRestored = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restoreProgress(),
          );
        }
        final local = widget.work.localOnly;
        const fallback = SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator()),
        );
        Widget body;
        if (_isPageMode) {
          body = PageView.builder(
            controller: _page,
            scrollDirection: _mode == 'horizontal'
                ? Axis.horizontal
                : Axis.vertical,
            onPageChanged: (i) {
              setState(() => _current = i);
              _persistProgressLocal(i + 1);
            },
            itemCount: sources.length,
            itemBuilder: (context, i) => InteractiveViewer(
              child: local
                  ? displayLocalImage(
                      sources[i],
                      fit: BoxFit.contain,
                      fallback: fallback,
                    )
                  : displayUrlImage(
                      sources[i],
                      fit: BoxFit.contain,
                      fallback: fallback,
                    ),
            ),
          );
        } else {
          // 滚动模式双指缩放：任一页放大时同步到所有页（见 _syncZoom），
          // 未缩放时单指滚动不受影响（InteractiveViewer 在 minScale 下让出手势）。
          body = ListView.builder(
            controller: _scroll,
            itemCount: sources.length,
            itemBuilder: (context, i) => InteractiveViewer(
              transformationController: _zoomControllerFor(i),
              minScale: 1,
              maxScale: 4,
              onInteractionUpdate: (_) => _syncZoom(i),
              onInteractionEnd: (_) => _endZoom(i),
              child: local
                  ? displayLocalImage(sources[i], fit: BoxFit.fitWidth)
                  : displayUrlImage(sources[i], fit: BoxFit.fitWidth),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final zoneW = constraints.maxWidth * 0.25;
            return Stack(
              children: [
                Positioned.fill(child: body),
                // 左边缘：上一页
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: zoneW,
                  child: GestureDetector(onTap: _prev),
                ),
                // 右边缘：下一页
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: zoneW,
                  child: GestureDetector(onTap: _next),
                ),
                // 中央：呼出/收起菜单
                Positioned(
                  left: zoneW,
                  right: zoneW,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      if (_consumeTapIfZoomed()) return;
                      setState(() => _menu = !_menu);
                    },
                  ),
                ),
                // 设置菜单（透明遮罩 + 顶栏/底栏）
                AnimatedOpacity(
                  opacity: _menu ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IgnorePointer(
                    ignoring: !_menu,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _topBar(context),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _bottomBar(),
                        ),
                      ],
                    ),
                  ),
                ),
                // 自动进行中：右上角小药丸提示，点按停止
                if (_autoSeconds > 0 && !_menu)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => _setAuto(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '自动 · ${_autoSeconds}s｜点按停止',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _topBar(BuildContext context) => Container(
    color: Colors.black87,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 16,
      bottom: 8,
    ),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(
            widget.work.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    ),
  );

  Widget _bottomBar() => Container(
    color: Colors.black87,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快捷跳转：进度条拖动 + 末端数字输入
          Row(
            children: [
              Text(
                '${_current + 1}/$_total',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Expanded(
                child: Slider(
                  value: _isPageMode ? _current.toDouble() : _scrollProgress,
                  min: 0,
                  max: (_total - 1).clamp(0, 1 << 30).toDouble(),
                  divisions: _total > 1 ? _total - 1 : 1,
                  onChanged: (v) {
                    if (_isPageMode) {
                      _page.jumpToPage(v.round());
                    } else {
                      setState(() => _scrollProgress = v);
                    }
                  },
                  onChangeEnd: (v) {
                    if (!_isPageMode && _scroll.hasClients) {
                      final max = _scroll.position.maxScrollExtent;
                      _scroll.animateTo(
                        _total > 1 ? max * v / (_total - 1) : 0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
              ),
              SizedBox(
                width: 64,
                child: _NumberInput(hintText: '页码', onSubmit: _jumpToPage),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('方向', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'horizontal', label: Text('左右')),
                  ButtonSegment(value: 'vertical', label: Text('上下')),
                ],
                selected: {_mode},
                onSelectionChanged: (v) {
                  setState(() => _mode = v.first);
                  _savePref('reader.manga.mode', v.first);
                },
              ),
            ],
          ),
          if (_mode == 'vertical') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('浏览', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('连续滚动')),
                    ButtonSegment(value: true, label: Text('逐页')),
                  ],
                  selected: {_snap},
                  onSelectionChanged: (v) {
                    setState(() => _snap = v.first);
                    _savePref('reader.manga.snap', '${v.first}');
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('自动', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 10),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('关')),
                  ButtonSegment(value: 3, label: Text('3秒')),
                  ButtonSegment(value: 5, label: Text('5秒')),
                  ButtonSegment(value: 10, label: Text('10秒')),
                  ButtonSegment(value: 30, label: Text('30秒')),
                ],
                selected: {_autoSeconds},
                onSelectionChanged: (v) => _setAuto(v.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('自定', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                child: _NumberInput(
                  hintText: '间隔秒',
                  onSubmit: (v) {
                    if (v >= 1 && v <= 3600) _setAuto(v);
                  },
                ),
              ),
              if (!_isPageMode) ...[
                const SizedBox(width: 16),
                const Text('滚距', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: Slider(
                    value: _scrollPercent.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 18,
                    label: '$_scrollPercent%',
                    onChanged: (v) =>
                        setState(() => _scrollPercent = v.round()),
                    onChangeEnd: (v) =>
                        _savePref('reader.manga.scrollPercent', '${v.round()}'),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: _NumberInput(
                    hintText: '%',
                    onSubmit: (v) {
                      if (v >= 10 && v <= 100) {
                        setState(() => _scrollPercent = v);
                        _savePref('reader.manga.scrollPercent', '$v');
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

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

/// 分页结果：每页文本行 + 每页起始段落下标（章节/书签跳转用）。
class NovelPages {
  const NovelPages(this.pages, this.startParas);

  final List<List<String>> pages;
  final List<int> startParas;

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
NovelPages paginateNovel(
  List<String> paragraphs, {
  required double contentWidth,
  required double contentHeight,
  required int fontSize,
  double lineHeight = 1.7,
  double lineSpacing = 2,
}) {
  final capacityUnits = contentWidth / fontSize;
  // 行渲染成本 = 行高 + 行距（Padding），必须与实际渲染一致，否则溢出
  final lineCost = fontSize * lineHeight + lineSpacing;
  final linesPerPage = (contentHeight / lineCost).floor().clamp(1, 1 << 20);

  final pages = <List<String>>[];
  final starts = <int>[];
  var current = <String>[];
  var budget = linesPerPage;
  var startPara = 0;

  void flush() {
    if (current.isEmpty) return;
    pages.add(current);
    starts.add(startPara);
    current = [];
    budget = linesPerPage;
  }

  for (var pi = 0; pi < paragraphs.length; pi++) {
    if (current.isEmpty) startPara = pi;
    final lines = wrapText(paragraphs[pi], capacityUnits);
    var idx = 0;
    while (idx < lines.length) {
      if (budget <= 0) {
        flush();
        startPara = pi; // 新页从当前段开始
      }
      final take = budget < lines.length - idx ? budget : lines.length - idx;
      current.addAll(lines.sublist(idx, idx + take));
      idx += take;
      budget -= take;
    }
  }
  flush();
  if (pages.isEmpty) pages.add(const []);
  return NovelPages(pages, starts);
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

/// 小说阅读器（沉浸）：中央点按菜单，左右边缘上一章/下一章；
/// 主题（白天/羊皮纸/夜间）、字号、亮度、章节选择、书签。
class _NovelReader extends ConsumerStatefulWidget {
  const _NovelReader({required this.work});

  final Work work;

  @override
  ConsumerState<_NovelReader> createState() => _NovelReaderState();
}

class _NovelReaderState extends ConsumerState<_NovelReader> {
  String _theme = 'day';
  double _brightness = 1.0;
  int _fontSize = 16;
  bool _menu = false;
  String _paging = 'scroll'; // scroll | page

  final _scroll = ScrollController();
  late final PageController _page = PageController();
  double _progress = 0; // 滚动模式进度 0..1
  int _currentPage = 0;

  // 进度持久化（同漫画侧：进阅读器恢复，退出落库 + 尽力推事件）
  bool _progressRestored = false;
  String _devName = 'dev';

  // 分页缓存（字号/尺寸/文本变化时重算）
  NovelPages? _pages;
  String _pagesKey = '';

  // 段落/推导章节缓存：滚动进度每帧 setState，全文切分+章节推导是 O(n)，
  // 不能每帧重算（百万字级会掉帧）；文本实例变化时才失效。
  String? _cachedText;
  List<String> _paragraphs = const [];
  List<({String title, int para})>? _derivedChapters;

  /// 段落序列（带缓存，见 [_cachedText]）。
  List<String> _parasOf(String content) {
    if (!identical(content, _cachedText)) {
      _cachedText = content;
      _paragraphs = novelParagraphs(content);
      _derivedChapters = null;
    }
    return _paragraphs;
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _resolveDevName();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (max > 0) {
        setState(() => _progress = (_scroll.offset / max).clamp(0.0, 1.0));
      }
    });
  }

  Future<void> _resolveDevName() async {
    _devName = await resolveDeviceName(ref.read(settingsRepositoryProvider));
  }

  /// 恢复上次阅读位置（首次文本就绪后调用一次）。
  Future<void> _restoreProgress() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final row = await (db.select(
        db.readingProgress,
      )..where((t) => t.workId.equals(widget.work.id))).getSingleOrNull();
      if (row == null || !mounted) return;
      final loc = jsonDecode(row.loc);
      if (loc is Map && loc['para'] is num) {
        _jumpToPara((loc['para'] as num).toInt());
      }
    } on Object {
      // 没有/坏掉的进度记录就从开头读
    }
  }

  Future<void> _loadPrefs() async {
    final repo = ref.read(settingsRepositoryProvider);
    final theme = await repo.get('reader.novel.themePreset');
    final fontSize = int.tryParse(
      await repo.get('reader.novel.fontSizePx') ?? '16',
    );
    final brightness = double.tryParse(
      await repo.get('reader.brightness') ?? '1.0',
    );
    final paging = await repo.get('reader.novel.paging');
    if (mounted) {
      setState(() {
        if (_NovelTheme.presets.containsKey(theme)) _theme = theme!;
        _fontSize = (fontSize ?? 16).clamp(12, 32);
        _brightness = (brightness ?? 1.0).clamp(0.3, 1.0);
        if (paging == 'scroll') _paging = 'scroll';
        if (paging == 'page') _paging = 'page';
      });
    }
  }

  Future<void> _savePref(String key, String value) =>
      ref.read(settingsRepositoryProvider).set(key, value);

  @override
  void dispose() {
    // 退出保存最终位置（本地 + 尽力推桶事件；失败只记日志）
    unawaited(
      saveProgressSafely(ref, widget.work, {
        'para': _currentPara,
      }, dev: _devName),
    );
    _scroll.dispose();
    _page.dispose();
    super.dispose();
  }

  int get _currentPara {
    final text = ref.read(_novelTextProvider(widget.work)).value;
    if (text == null) return 0;
    final total = _parasOf(text).length;
    if (_paging == 'page') {
      final pages = _pages;
      if (pages == null || pages.startParas.isEmpty) return 0;
      final p = _currentPage.clamp(0, pages.startParas.length - 1);
      return pages.startParas[p].clamp(0, total);
    }
    return (total * _progress).round().clamp(0, total);
  }

  void _jumpToPara(int para) {
    final text = ref.read(_novelTextProvider(widget.work)).value;
    if (text == null) return;
    final total = _parasOf(text).length;
    if (total <= 0) return;
    if (_paging == 'page') {
      final pages = _pages;
      if (pages == null || pages.length == 0) return;
      _page.jumpToPage(pages.pageOfPara(para.clamp(0, total - 1)));
      return;
    }
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.animateTo(
      max * (para / total).clamp(0.0, 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// 按窗口尺寸/字号分页（带缓存，重算成本与文本量成正比）。
  NovelPages _paginate(List<String> paragraphs, BoxConstraints c) {
    final key =
        '${paragraphs.length}:${paragraphs.firstOrNull}:${paragraphs.lastOrNull}'
        ':$_fontSize:${c.maxWidth}x${c.maxHeight}';
    if (_pages != null && _pagesKey == key) return _pages!;
    _pages = paginateNovel(
      paragraphs,
      contentWidth: (c.maxWidth - 40).clamp(50, 1 << 20).toDouble(),
      contentHeight: (c.maxHeight - 80).clamp(50, 1 << 20).toDouble(),
      fontSize: _fontSize,
    );
    _pagesKey = key;
    return _pages!;
  }

  List<({String title, int para})> _chaptersOf(
    String text,
    List<({String title, int para})>? fromFile,
  ) {
    if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    _parasOf(text);
    return _derivedChapters ??= deriveChapters(_paragraphs);
  }

  void _jumpChapter(int direction, List<({String title, int para})> chapters) {
    if (chapters.isEmpty) {
      _jumpToPara((_currentPara + direction * 200).clamp(0, 1 << 30));
      return;
    }
    final cur = _currentPara;
    var target = chapters.first;
    if (direction > 0) {
      for (final c in chapters) {
        if (c.para > cur) {
          target = c;
          break;
        }
        target = c;
      }
      if (target.para <= cur && chapters.last.para <= cur) return; // 已是末章
    } else {
      for (final c in chapters) {
        if (c.para >= cur) break;
        target = c;
      }
    }
    _jumpToPara(target.para);
  }

  Future<void> _addBookmark(List<String> paragraphs) async {
    final para = _currentPara;
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id =
        'bm_${now.microsecondsSinceEpoch}_${Random().nextInt(1 << 16).toRadixString(36)}';
    final note = paragraphs.isNotEmpty && para < paragraphs.length
        ? paragraphs[para].substring(
            0,
            paragraphs[para].length > 24 ? 24 : paragraphs[para].length,
          )
        : '';
    await db
        .into(db.bookmarks)
        .insert(
          BookmarksCompanion(
            id: Value(id),
            workId: Value(widget.work.id),
            loc: Value('{"para":$para}'),
            note: Value(note),
            color: const Value('red'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    unawaited(
      appendReaderEventSafely(
        ref,
        bookmarkEvent(
          dev: _devName,
          id: id,
          work: widget.work.id,
          loc: {'para': para},
          note: note,
        ),
      ),
    );
  }

  Future<void> _removeBookmark(String id) async {
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.bookmarks)..where((t) => t.id.equals(id))).go();
    unawaited(
      appendReaderEventSafely(ref, bookmarkDeleteEvent(dev: _devName, id: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = ref.watch(_novelTextProvider(widget.work));
    final chaptersFile = ref.watch(_chaptersFileProvider(widget.work));
    final bookmarks =
        ref.watch(_bookmarksProvider(widget.work.id)).value ??
        const <Bookmark>[];
    final preset = _NovelTheme.presets[_theme]!;

    return text.when(
      loading: () => Scaffold(
        backgroundColor: preset.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('加载失败: $e'))),
      data: (content) {
        final paragraphs = _parasOf(content);
        final chapters = _chaptersOf(content, chaptersFile.value);
        if (!_progressRestored) {
          _progressRestored = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restoreProgress(),
          );
        }
        return Scaffold(
          backgroundColor: preset.bg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final zoneW = constraints.maxWidth * 0.25;
              final pages = _paginate(paragraphs, constraints);
              final pageCount = pages.length;
              if (_currentPage >= pageCount) {
                _currentPage = pageCount - 1;
              }
              return Stack(
                children: [
                  Positioned.fill(
                    child: _paging == 'page'
                        ? PageView.builder(
                            controller: _page,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            itemCount: pageCount,
                            itemBuilder: (context, page) => Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                40,
                                20,
                                40,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final line in pages.pages[page])
                                    SizedBox(
                                      // 固定行高 = 分页预算的行成本，保证整页不溢出
                                      height: _fontSize * 1.7 + 2,
                                      child: Text(
                                        line,
                                        style: TextStyle(
                                          fontSize: _fontSize.toDouble(),
                                          height: 1.7,
                                          color: preset.fg,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
                            itemCount: paragraphs.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SelectableText(
                                paragraphs[i],
                                style: TextStyle(
                                  fontSize: _fontSize.toDouble(),
                                  height: 1.7,
                                  color: preset.fg,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // 亮度遮罩
                  if (_brightness < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(
                            alpha: 1 - _brightness,
                          ),
                        ),
                      ),
                    ),
                  // 左边缘：翻页模式上一页 / 滚动模式上一章
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: zoneW,
                    child: GestureDetector(
                      onTap: _paging == 'page'
                          ? () => _page.previousPage(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                            )
                          : () => _jumpChapter(-1, chapters),
                    ),
                  ),
                  // 右边缘：翻页模式下一页 / 滚动模式下一章
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: zoneW,
                    child: GestureDetector(
                      onTap: _paging == 'page'
                          ? () => _page.nextPage(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                            )
                          : () => _jumpChapter(1, chapters),
                    ),
                  ),
                  // 中央：菜单
                  Positioned(
                    left: zoneW,
                    right: zoneW,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _menu = !_menu),
                    ),
                  ),
                  // 菜单
                  AnimatedOpacity(
                    opacity: _menu ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: IgnorePointer(
                      ignoring: !_menu,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _topBar(preset),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _bottomBar(preset, paragraphs, chapters),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 书签浮动入口：菜单收起时常驻右上角，点按直达书签列表
                  if (!_menu && bookmarks.isNotEmpty)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => _showBookmarksSheet(paragraphs, preset),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: preset.bg.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: preset.fg.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark, size: 14, color: preset.fg),
                              const SizedBox(width: 4),
                              Text(
                                '${bookmarks.length}',
                                style: TextStyle(
                                  color: preset.fg,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _topBar(_NovelTheme preset) => Container(
    color: preset.bg.withValues(alpha: 0.95),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 16,
      bottom: 8,
    ),
    child: Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: preset.fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(
            widget.work.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: preset.fg, fontSize: 15),
          ),
        ),
      ],
    ),
  );

  Widget _bottomBar(
    _NovelTheme preset,
    List<String> paragraphs,
    List<({String title, int para})> chapters,
  ) => Container(
    color: preset.bg.withValues(alpha: 0.95),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('翻页', style: TextStyle(color: preset.fg)),
              const SizedBox(width: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'scroll', label: Text('滚动')),
                  ButtonSegment(value: 'page', label: Text('逐页')),
                ],
                selected: {_paging},
                onSelectionChanged: (v) {
                  setState(() => _paging = v.first);
                  _savePref('reader.novel.paging', v.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('主题', style: TextStyle(color: preset.fg)),
              const SizedBox(width: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'day', label: Text('白天')),
                  ButtonSegment(value: 'parchment', label: Text('羊皮纸')),
                  ButtonSegment(value: 'night', label: Text('夜间')),
                ],
                selected: {_theme},
                onSelectionChanged: (v) {
                  setState(() => _theme = v.first);
                  _savePref('reader.novel.themePreset', v.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('字号', style: TextStyle(color: preset.fg)),
              Expanded(
                child: Slider(
                  value: _fontSize.toDouble(),
                  min: 12,
                  max: 32,
                  divisions: 20,
                  label: '$_fontSize',
                  onChanged: (v) => setState(() => _fontSize = v.round()),
                  onChangeEnd: (v) =>
                      _savePref('reader.novel.fontSizePx', '${v.round()}'),
                ),
              ),
              Text('亮度', style: TextStyle(color: preset.fg)),
              Expanded(
                child: Slider(
                  value: _brightness,
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  label: '${(_brightness * 100).round()}%',
                  onChanged: (v) => setState(() => _brightness = v),
                  onChangeEnd: (v) => _savePref('reader.brightness', '$v'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.list),
                label: Text(
                  '章节 ${chapters.length}',
                  style: TextStyle(color: preset.fg),
                ),
                onPressed: chapters.isEmpty
                    ? null
                    : () => _showChaptersSheet(chapters, preset),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.bookmark_border),
                label: Text('书签', style: TextStyle(color: preset.fg)),
                onPressed: () => _showBookmarksSheet(paragraphs, preset),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _showChaptersSheet(
    List<({String title, int para})> chapters,
    _NovelTheme preset,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: preset.bg,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in chapters)
              ListTile(
                dense: true,
                title: Text(c.title, style: TextStyle(color: preset.fg)),
                onTap: () {
                  Navigator.of(context).pop();
                  _jumpToPara(c.para);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showBookmarksSheet(List<String> paragraphs, _NovelTheme preset) {
    final bookmarks =
        ref.read(_bookmarksProvider(widget.work.id)).value ??
        const <Bookmark>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: preset.bg,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_add),
                label: const Text('添加当前位置书签'),
                onPressed: () async {
                  await _addBookmark(paragraphs);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
            for (final b in bookmarks)
              ListTile(
                dense: true,
                leading: Icon(Icons.bookmark, color: preset.fg),
                title: Text(
                  b.note.isEmpty ? '书签' : b.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: preset.fg),
                ),
                subtitle: Text(
                  b.loc,
                  style: TextStyle(color: preset.fg.withValues(alpha: 0.6)),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  final m = RegExp(r'"para":(\d+)').firstMatch(b.loc);
                  if (m != null) _jumpToPara(int.parse(m.group(1)!));
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    await _removeBookmark(b.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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

part of 'reader_page.dart';

// 漫画阅读器（自 reader_page.dart 拆出，行为不变）。

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
  double? _pagePreview; // 滑条预览独立于滚动回调；松手才提交源页码。
  final Set<int> _touches = {};
  final Map<int, Offset> _touchPositions = {};
  double? _pinchDistance;
  Offset _pinchFocal = Offset.zero;
  Matrix4 _pinchTransform = Matrix4.identity();
  bool _suppressTap = false;
  DateTime _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);

  void _beginPinch() {
    final points = _touchPositions.values.take(2).toList();
    _pinchDistance = max((points[1] - points[0]).distance, 1);
    _pinchFocal = (points[0] + points[1]) / 2;
    _pinchTransform = _zoomControllerFor(0).value.clone();
    _suppressTap = true;
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset);
    if (_page.hasClients) _page.jumpTo(_page.offset);
    setState(() {});
  }

  void _moveTouch(PointerMoveEvent event, Size viewport) {
    final previous = _touchPositions[event.pointer];
    if (previous == null) return;
    _touchPositions[event.pointer] = event.localPosition;
    final controller = _zoomControllerFor(0);
    double scale;
    Offset translation;
    if (_touchPositions.length >= 2 && _pinchDistance != null) {
      final points = _touchPositions.values.take(2).toList();
      final initialScale = _pinchTransform.getMaxScaleOnAxis();
      scale =
          (initialScale * (points[1] - points[0]).distance / _pinchDistance!)
              .clamp(1.0, 4.0);
      final focal = (points[0] + points[1]) / 2;
      final initialTranslation = Offset(
        _pinchTransform.storage[12],
        _pinchTransform.storage[13],
      );
      translation =
          focal - (_pinchFocal - initialTranslation) * (scale / initialScale);
    } else if (_zoom > 1.02) {
      scale = _zoom;
      translation =
          Offset(controller.value.storage[12], controller.value.storage[13]) +
          event.localPosition -
          previous;
    } else {
      return;
    }
    final matrix = Matrix4.diagonal3Values(scale, scale, 1);
    matrix.setTranslationRaw(
      translation.dx.clamp(-viewport.width * (scale - 1), 0.0),
      translation.dy.clamp(-viewport.height * (scale - 1), 0.0),
      0,
    );
    controller.value = matrix;
    _syncZoom(0);
  }

  void _endTouch(int pointer) {
    _touches.remove(pointer);
    _touchPositions.remove(pointer);
    _lastInteraction = DateTime.now();
    if (_touchPositions.length >= 2) {
      _beginPinch();
    } else {
      _pinchDistance = null;
      if (_touchPositions.isEmpty) _endZoom(0);
      setState(() {});
    }
  }

  int _autoSeconds = 5; // 自动翻页/滚动间隔，0 = 关
  int _scrollPercent = 92; // 连续滚动一次跳转的距离（可视高度百分比）
  bool _doublePage = false; // 双页对开（仅横翻模式生效）

  // 横图探测：页码 → 引擎解码出的尺寸；结果回流后重算 spread。
  // 探测经 ImageProvider.resolve 走引擎编解码（非主 isolate 纯 Dart 解码），
  // 且只扫「当前首 −2 ~ +9」的有界窗口——200 页不全量解码。
  final Map<int, Size> _dims = {};
  final Set<int> _probePending = <int>{}; // LinkedHashSet 保序
  bool _probeDraining = false;

  // 进度持久化：进阅读器恢复上次位置；页变化落本地（防抖），退出写事件。
  // [_userInteracted]：用户先动了手（翻页/滑动）就不再用旧进度覆盖——
  // 否则恢复读库慢于用户手势时，会把人拽回上次保存的位置。
  bool _progressRestored = false;
  bool _userInteracted = false;
  String _devName = 'dev';
  int _lastPersistedPage = 0;

  // dispose 里不能用 WidgetRef（Riverpod 抛 Bad state），挂载期缓存依赖。
  late final AppDatabase _db;
  BucketClient? _bucketClient;
  bool _depsCached = false;

  // 跳页将目标页设为双向列表的零点，无须估计尚未加载的图片高度。
  int _scrollAnchor = 0;
  final _scrollCenter = GlobalKey();
  final Map<int, GlobalKey> _itemKeys = {};
  final Map<int, double> _measured = {}; // index → 项顶部距滚动起点
  int _scrollJumpToken = 0;
  bool _progressFrameScheduled = false;

  Timer? _autoTimer;
  late final PageController _page = PageController();
  final ScrollController _scroll = ScrollController(keepScrollOffset: false);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _scroll.addListener(_onScrollProgress);
    _resolveDevName();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsCached) return;
    _depsCached = true;
    _db = ref.read(appDatabaseProvider);
    _bucketClient = ref.read(bucketClientProvider);
  }

  Future<void> _resolveDevName() async {
    _devName = await resolveDeviceName(ref.read(settingsRepositoryProvider));
  }

  void _onScrollProgress() {
    if (_progressFrameScheduled || _isPageMode || !_scroll.hasClients) return;
    _progressFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progressFrameScheduled = false;
      if (!mounted || _isPageMode || !_scroll.hasClients || _total <= 1) return;
      _measureBuiltItems();
      final page = _topPageAt(_scroll.offset).toDouble();
      if (_scrollProgress != page) setState(() => _scrollProgress = page);
      _persistProgressLocal(page.round() + 1);
    });
  }

  /// 当前视口顶部对应的源页码，无样本时保留跳转锚点。
  int _topPageAt(double offset) {
    var best = -1;
    _measured.forEach((i, o) {
      if (o <= offset + 1 && i > best) best = i;
    });
    if (best >= 0) return best.clamp(0, _total - 1);
    return _scrollAnchor;
  }

  /// 布局后测量当前已构建页，图片加载/窗口变化后不沿用过期高度。
  void _measureBuiltItems() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final scrollBox = pos.context.storageContext.findRenderObject();
    if (scrollBox is! RenderBox || !scrollBox.hasSize) return;
    _measured.clear();
    final scrollDy = scrollBox.localToGlobal(Offset.zero).dy;
    for (final e in _itemKeys.entries) {
      final box = e.value.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final dy = box.localToGlobal(Offset.zero).dy;
        // 只采视口附近的样本：远离视口的未构建/将回收，测不到也正常
        if (dy > -4000 && dy < 8000) {
          _measured[e.key] = pos.pixels + (dy - scrollDy);
        }
      }
    }
  }

  void _jumpScrollToIndex(int index) {
    ++_scrollJumpToken;
    _measured.clear();
    _itemKeys.clear();
    setState(() => _scrollAnchor = index);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    final token = _scrollJumpToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _scrollJumpToken || !_scroll.hasClients) return;
      _measureBuiltItems();
      setState(() => _scrollProgress = index.toDouble());
      _persistProgressLocal(index + 1);
    });
  }

  /// 恢复上次阅读位置（首次页面就绪后调用一次；用户已动过手则放弃）。
  Future<void> _restoreProgress() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final row = await (db.select(
        db.readingProgress,
      )..where((t) => t.workId.equals(widget.work.id))).getSingleOrNull();
      if (row == null || !mounted || _userInteracted) return;
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

  // ------------------------------------------------------------ 书签
  // 坐标 loc = {"page":N}（1 基，与进度事件同坐标系）；事件与重放链路
  // 与小说侧共用（bookmarkEvent / bookmarkDeleteEvent / appendReaderEventSafely）。

  int get _currentPage1Based => _isPageMode
      ? _displayFirstPage(_current) + 1
      : _scrollProgress.round() + 1;

  Future<void> _addBookmark() async {
    final page = _currentPage1Based;
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id =
        'bm_${now.microsecondsSinceEpoch}_${Random().nextInt(1 << 16).toRadixString(36)}';
    await db
        .into(db.bookmarks)
        .insert(
          BookmarksCompanion(
            id: Value(id),
            workId: Value(widget.work.id),
            loc: Value('{"page":$page}'),
            color: const Value('red'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    unawaited(
      appendReaderEventSafely(
        ref.read(bucketClientProvider),
        bookmarkEvent(
          dev: _devName,
          id: id,
          work: widget.work.id,
          loc: {'page': page},
        ),
      ),
    );
  }

  Future<void> _removeBookmark(String id) async {
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.bookmarks)..where((t) => t.id.equals(id))).go();
    unawaited(
      appendReaderEventSafely(
        ref.read(bucketClientProvider),
        bookmarkDeleteEvent(dev: _devName, id: id),
      ),
    );
  }

  /// 书签列表弹层：缩略图取页面源（本地路径 / 预签名 URL 与正页同一缓存），
  /// 点击跳页、删除不关层（列表是 StreamProvider 自动刷新）。
  void _showBookmarksSheet(List<String> sources, bool local) {
    final bookmarks =
        ref.read(_bookmarksProvider(widget.work.id)).value ??
        const <Bookmark>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_add, color: Colors.white70),
                label: const Text(
                  '添加书签（当前页）',
                  style: TextStyle(color: Colors.white70),
                ),
                onPressed: () async {
                  await _addBookmark();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
            if (bookmarks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('还没有书签', style: TextStyle(color: Colors.white38)),
                ),
              )
            else
              for (final b in bookmarks)
                Builder(
                  builder: (context) {
                    final m = RegExp(r'"page":(\d+)').firstMatch(b.loc);
                    final page = m != null ? int.parse(m.group(1)!) : 0;
                    final idx = page - 1;
                    final thumb = (idx >= 0 && idx < sources.length)
                        ? SizedBox(
                            width: 48,
                            height: 64,
                            child: local
                                ? displayLocalImage(
                                    sources[idx],
                                    fit: BoxFit.cover,
                                  )
                                : displayUrlImage(
                                    sources[idx],
                                    fit: BoxFit.cover,
                                  ),
                          )
                        : const SizedBox(
                            width: 48,
                            height: 64,
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white38,
                            ),
                          );
                    return ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: thumb,
                      ),
                      title: Text(
                        '第 $page 页',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(b.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _jumpToPage(page);
                      },
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.white54,
                        ),
                        onPressed: () => _removeBookmark(b.id),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
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
    final doublePage = await repo.get('reader.manga.doublePage');
    if (mounted) {
      setState(() {
        if (mode == 'horizontal') _mode = 'horizontal';
        if (mode == 'vertical') _mode = 'vertical';
        _snap = snap == 'true';
        _autoSeconds = auto ?? 5;
        _scrollPercent = (scrollPercent ?? 92).clamp(10, 100);
        _doublePage = doublePage == 'true';
      });
      _restartAuto();
    }
  }

  // ------------------------------------------------------------ 自动翻页

  Future<void> _savePref(String key, String value) =>
      ref.read(settingsRepositoryProvider).set(key, value);

  /// 双页对开开关：显示下标语义在页下标/spread 下标间切换，
  /// 切换前后都锚定「首页面码」，不重定位、不跳页。
  void _setDoublePage(bool on) {
    final anchor = _displayFirstPage(_current);
    setState(() => _doublePage = on);
    _savePref('reader.manga.doublePage', '$on');
    final idx = _isDoubleMode ? spreadIndexForPage(_spreads, anchor) : anchor;
    setState(() => _current = idx);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _page.hasClients) _page.jumpToPage(idx);
    });
  }

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
    if (_total == 0 ||
        _menu ||
        _pagePreview != null ||
        _touches.isNotEmpty ||
        _zoom > 1.02 ||
        DateTime.now().difference(_lastInteraction) <
            const Duration(seconds: 3)) {
      return;
    }
    if (_isPageMode) {
      if (!_page.hasClients || _page.position.isScrollingNotifier.value) return;
      if (_current >= _dispCount - 1) {
        _setAuto(0);
        return;
      }
      _page.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      if (!_scroll.hasClients) return;
      if (_scroll.position.isScrollingNotifier.value) return;
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
      saveProgressSafely(_db, _bucketClient, widget.work, {
        // 对开模式 _current 是 spread 下标，落库必须是首页面码（1 基）
        'page': _isPageMode
            ? _displayFirstPage(_current) + 1
            : _scrollProgress.round() + 1,
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

  /// 双页对开实际生效条件：开关开 + 横翻模式（纵向配对无意义）。
  bool get _isDoubleMode => _doublePage && _mode == 'horizontal';

  /// 当前显示单元的总页数（对开 = spread 数；否则 = 页数）。
  int get _dispCount => _isDoubleMode ? _spreads.length : _total;

  /// spread 列表随探测结果增量重算（乐观配对，见 computeSpreads）。
  List<Spread> get _spreads => computeSpreads(_total, {
    for (final e in _dims.entries)
      if (isWideImage(e.value)) e.key,
  });

  /// 显示下标 → 该单元首页面码（0 基；单页模式恒等映射）。
  int _displayFirstPage(int displayIndex) => _isDoubleMode
      ? _spreads[displayIndex.clamp(0, _spreads.length - 1)].first
      : displayIndex;

  void _prev() {
    if (_consumeTapIfZoomed()) return;
    _userInteracted = true;
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
    _userInteracted = true;
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
    ++_scrollJumpToken;
    final step =
        _scroll.position.viewportDimension * _scrollPercent / 100 * direction;
    final target = _scroll.offset + step;
    _scroll.animateTo(
      target.clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// 跳转到指定页（1 基）。滚动模式走 [_jumpScrollToIndex]：
  /// 页高不等，直接按线性比例 animateTo 会落在错误的页上。
  /// 对开模式先把页码映射到 spread 下标。
  void _jumpToPage(int page) {
    if (_total <= 0) return;
    _userInteracted = true;
    final target = page.clamp(1, _total);
    final idx = _isDoubleMode
        ? spreadIndexForPage(_spreads, target - 1)
        : target - 1;
    if (_isPageMode) {
      _page.jumpToPage(idx);
    } else if (_scroll.hasClients) {
      _jumpScrollToIndex(target - 1);
    }
    setState(() {
      _current = idx;
      _scrollProgress = (target - 1).toDouble();
    });
  }

  void _setSnap(bool snap) {
    final anchor = _currentPage1Based;
    ++_scrollJumpToken;
    setState(() {
      _snap = snap;
      _current = anchor - 1;
      _scrollProgress = (anchor - 1).toDouble();
    });
    _savePref('reader.manga.snap', '$snap');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpToPage(anchor);
    });
  }

  void _setMode(String mode) {
    if (mode == _mode) return;
    ++_scrollJumpToken;
    final anchor = _isPageMode
        ? _displayFirstPage(_current)
        : _scrollProgress.round();
    setState(() {
      _mode = mode;
      _current = _isDoubleMode
          ? spreadIndexForPage(_spreads, anchor)
          : anchor.clamp(0, (_total - 1).clamp(0, 1 << 30));
      _scrollProgress = anchor.toDouble();
    });
    _savePref('reader.manga.mode', mode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isPageMode && _page.hasClients) {
        _page.jumpToPage(_current.clamp(0, (_dispCount - 1).clamp(0, 1 << 30)));
      } else if (!_isPageMode && _scroll.hasClients) {
        _jumpScrollToIndex(_current);
      }
    });
  }

  // ------------------------------------------------------------ 横图探测

  /// 请求探测一页尺寸（去重 + 保序入队，立即驱动顺序单发队列）。
  void _requestProbe(List<String> sources, bool local, int page) {
    if (page < 0 || page >= sources.length) return;
    if (_dims.containsKey(page) || _probePending.contains(page)) return;
    _probePending.add(page);
    _drainProbes(sources, local);
  }

  /// 探测当前 spread 首 −2 ~ +9 的未探测页（有界窗口）。
  void _seedProbesAround(List<String> sources, bool local, int displayIndex) {
    if (!_isDoubleMode) return;
    final first = _displayFirstPage(displayIndex);
    for (var p = first - 2; p <= first + 9 && p < sources.length; p++) {
      _requestProbe(sources, local, p);
    }
  }

  /// 顺序单发消费队列：任何时刻只有一个在飞探测，防并发解码打爆 IO。
  Future<void> _drainProbes(List<String> sources, bool local) async {
    if (_probeDraining) return;
    _probeDraining = true;
    try {
      while (_probePending.isNotEmpty && mounted) {
        final page = _probePending.first;
        _probePending.remove(page);
        if (_dims.containsKey(page)) continue;
        final size = await _probeImageSize(sources[page], local);
        if (!mounted || size == null || _dims.containsKey(page)) continue;
        // 重算不变量：先记锚点（当前首页面码），写入尺寸后找回 spread 下标，
        // 分裂/合并只校正显示位置，绝不跳页。
        final anchor = _displayFirstPage(_current);
        setState(() => _dims[page] = size);
        if (!_isDoubleMode) continue;
        final idx = spreadIndexForPage(_spreads, anchor);
        if (idx != _current) {
          _current = idx;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _page.hasClients) _page.jumpToPage(idx);
          });
        }
      }
    } finally {
      _probeDraining = false;
    }
  }

  /// 经 ImageProvider 取首帧宽高（引擎编解码；AVIF 走 flutter_avif）。
  /// 取完 dispose 图像并驱逐缓存——探测不该把整页留守内存。
  Future<Size?> _probeImageSize(String source, bool local) async {
    try {
      final ImageProvider provider;
      if (local) {
        provider = p.extension(source).toLowerCase() == '.avif'
            ? FileAvifImage(File(source))
            : FileImage(File(source));
      } else {
        // 与显示层共享下载缓存（cacheImageFile 幂等），探测不触发二次下载
        final path = await cacheImageFile(source);
        provider = p.extension(path).toLowerCase() == '.avif'
            ? FileAvifImage(File(path))
            : FileImage(File(path));
      }
      final completer = Completer<Size?>();
      final stream = provider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          stream.removeListener(listener);
          final img = info.image;
          final size = Size(img.width.toDouble(), img.height.toDouble());
          img.dispose();
          imageCache.evict(provider);
          if (!completer.isCompleted) completer.complete(size);
        },
        onError: (e, _) {
          stream.removeListener(listener);
          imageCache.evict(provider);
          if (!completer.isCompleted) completer.complete(null);
        },
      );
      stream.addListener(listener);
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => null,
      );
    } on Object {
      return null;
    }
  }

  /// 单页渲染（单页/对开两半共用）；fallback 与正页一致。
  Widget _pageImage(List<String> sources, int i, bool local, BoxFit fit) {
    const fallback = SizedBox(
      height: 400,
      child: Center(child: CircularProgressIndicator()),
    );
    return local
        ? displayLocalImage(sources[i], fit: fit, fallback: fallback)
        : displayUrlImage(sources[i], fit: fit, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(_pageSourcesProvider(widget.work));
    return pages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败: $e', textAlign: TextAlign.center),
                  if (widget.work.localOnly) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '本地文件缺失：可能下载未完成就退出了应用，或文件被清理；'
                      '可回书架长按该作品移除记录',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 报错页必须有回退口：无 appBar 的阅读器一旦加载失败，
          // 没有返回键会被困在本页（书源下载中的占位书点开必撞）
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
      data: (sources) {
        if (sources.isEmpty) return const Center(child: Text('没有页面'));
        _total = sources.length;
        if (_current >= _dispCount) _current = _dispCount - 1;
        if (!_progressRestored) {
          _progressRestored = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restoreProgress(),
          );
        }
        if (_isDoubleMode) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _seedProbesAround(sources, widget.work.localOnly, _current),
          );
        }
        final local = widget.work.localOnly;
        final bookmarks =
            ref.watch(_bookmarksProvider(widget.work.id)).value ??
            const <Bookmark>[];
        Widget body;
        if (_isPageMode) {
          body = PageView.builder(
            controller: _page,
            physics: _zoom > 1.02 || _pinchDistance != null
                ? const NeverScrollableScrollPhysics()
                : null,
            scrollDirection: _mode == 'horizontal'
                ? Axis.horizontal
                : Axis.vertical,
            onPageChanged: (i) {
              _userInteracted = true;
              setState(() => _current = i);
              _persistProgressLocal(_displayFirstPage(i) + 1);
              _seedProbesAround(sources, local, i);
            },
            itemCount: _dispCount,
            itemBuilder: (context, i) {
              // 双页对开：一个显示单元 = 一个 spread（两页并排或横图独占）
              if (_isDoubleMode) {
                final spreads = _spreads;
                if (spreads.isEmpty) {
                  return _pageImage(sources, 0, local, BoxFit.contain);
                }
                final spread = spreads[i.clamp(0, spreads.length - 1)];
                final child = spread.len == 2
                    ? Row(
                        children: [
                          Expanded(
                            child: _pageImage(
                              sources,
                              spread.first,
                              local,
                              BoxFit.contain,
                            ),
                          ),
                          Expanded(
                            child: _pageImage(
                              sources,
                              spread.first + 1,
                              local,
                              BoxFit.contain,
                            ),
                          ),
                        ],
                      )
                    : _pageImage(sources, spread.first, local, BoxFit.contain);
                return child;
              }
              return _pageImage(sources, i, local, BoxFit.contain);
            },
          );
        } else {
          // 缩放放在整个列表外层，让列表先参加单指拖动的手势竞争。
          Widget item(int i) => Container(
            key: _itemKeys.putIfAbsent(i, GlobalKey.new),
            child: local
                ? displayLocalImage(
                    sources[i],
                    fit: BoxFit.fitWidth,
                    loadingPlaceholder: const SizedBox(height: 400),
                  )
                : displayUrlImage(
                    sources[i],
                    fit: BoxFit.fitWidth,
                    loadingPlaceholder: const SizedBox(height: 400),
                  ),
          );
          body = NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _onScrollProgress();
              return false;
            },
            child: CustomScrollView(
              key: ValueKey(_scrollAnchor),
              controller: _scroll,
              physics: _zoom > 1.02 || _pinchDistance != null
                  ? const NeverScrollableScrollPhysics()
                  : null,
              center: _scrollCenter,
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => item(_scrollAnchor - i - 1),
                    childCount: _scrollAnchor,
                  ),
                ),
                SliverList(
                  key: _scrollCenter,
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => item(_scrollAnchor + i),
                    childCount: sources.length - _scrollAnchor,
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final zoneW = constraints.maxWidth * 0.25;
            return Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: (event) {
                      if (_touches.isEmpty) _suppressTap = false;
                      _touches.add(event.pointer);
                      _touchPositions[event.pointer] = event.localPosition;
                      if (_touchPositions.length == 2) _beginPinch();
                      _userInteracted = true;
                      _lastInteraction = DateTime.now();
                      ++_scrollJumpToken;
                    },
                    onPointerMove: (event) =>
                        _moveTouch(event, constraints.biggest),
                    onPointerUp: (event) => _endTouch(event.pointer),
                    onPointerCancel: (event) => _endTouch(event.pointer),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (event) {
                        if (_suppressTap) return;
                        if (event.localPosition.dx < zoneW) {
                          _prev();
                        } else if (event.localPosition.dx >
                            constraints.maxWidth - zoneW) {
                          _next();
                        } else {
                          if (_consumeTapIfZoomed()) return;
                          setState(() => _menu = !_menu);
                        }
                      },
                      child: InteractiveViewer(
                        transformationController: _zoomControllerFor(0),
                        panEnabled: false,
                        scaleEnabled: false,
                        minScale: 1,
                        maxScale: 4,
                        child: body,
                      ),
                    ),
                  ),
                ),
                // 设置菜单（透明遮罩 + 顶栏/底栏）
                AnimatedOpacity(
                  opacity: _menu ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IgnorePointer(
                    ignoring: !_menu,
                    child: Column(
                      children: [
                        _topBar(context),
                        Expanded(
                          child: IgnorePointer(
                            child: Row(
                              children: [
                                _touchGuide(
                                  1,
                                  _isPageMode ? '点按左侧\n上一页' : '点按左侧\n向上翻屏',
                                ),
                                _touchGuide(
                                  2,
                                  '点按中间\n显示 / 收起菜单\n单指滑动浏览 · 双指缩放',
                                ),
                                _touchGuide(
                                  1,
                                  _isPageMode ? '点按右侧\n下一页' : '点按右侧\n向下翻屏',
                                ),
                              ],
                            ),
                          ),
                        ),
                        _bottomBar(sources, local),
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
                // 书签浮动入口：常驻右上角；自动翻页药丸开启时错到其下方
                if (!_menu && bookmarks.isNotEmpty)
                  Positioned(
                    top:
                        MediaQuery.of(context).padding.top +
                        (_autoSeconds > 0 ? 44 : 8),
                    right: 16,
                    child: GestureDetector(
                      onTap: () => _showBookmarksSheet(sources, local),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark,
                              size: 14,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '书签',
                              style: TextStyle(
                                color: Colors.white70,
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
        );
      },
    );
  }

  Widget _touchGuide(int flex, String text) => Expanded(
    flex: flex,
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ),
    ),
  );

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

  Widget _controlGroup(String label, Widget control) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      const SizedBox(width: 8),
      Flexible(
        child: FittedBox(fit: BoxFit.scaleDown, child: control),
      ),
    ],
  );

  Widget _bottomBar(List<String> sources, bool local) => Container(
    key: const ValueKey('manga-reader-controls'),
    color: Colors.black87,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: min(300, MediaQuery.sizeOf(context).height * 0.45),
        ),
        child: SingleChildScrollView(
          child: Theme(
            data: Theme.of(context).copyWith(
              segmentedButtonTheme: const SegmentedButtonThemeData(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 快捷跳转：进度条拖动 + 末端数字输入
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _pagePreview != null
                        ? '第 ${_pagePreview!.round() + 1} 页/共 $_total 页'
                        : _isDoubleMode && _spreads.isNotEmpty
                        ? '第 ${_displayFirstPage(_current) + 1}-${_displayFirstPage(_current) + _spreads[_current.clamp(0, _spreads.length - 1)].len} 页/共 $_total 页'
                        : '$_currentPage1Based/$_total',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        key: const ValueKey('manga-page-slider'),
                        value:
                            (_pagePreview ??
                                    (_currentPage1Based - 1).toDouble())
                                .clamp(0, _total - 1),
                        min: 0,
                        max: (_total - 1).toDouble(),
                        divisions: _total > 1 ? _total - 1 : null,
                        label:
                            '第 ${(_pagePreview ?? (_currentPage1Based - 1)).round() + 1} 页',
                        onChangeStart: _total <= 1
                            ? null
                            : (v) {
                                _userInteracted = true;
                                _lastInteraction = DateTime.now();
                                ++_scrollJumpToken;
                                setState(() => _pagePreview = v);
                              },
                        onChanged: _total <= 1
                            ? null
                            : (v) => setState(() => _pagePreview = v),
                        onChangeEnd: _total <= 1
                            ? null
                            : (v) {
                                _lastInteraction = DateTime.now();
                                setState(() => _pagePreview = null);
                                _jumpToPage(v.round() + 1);
                              },
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: _NumberInput(
                        hintText: '页码',
                        onSubmit: _jumpToPage,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _controlGroup(
                      '方向',
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'horizontal', label: Text('左右')),
                          ButtonSegment(value: 'vertical', label: Text('上下')),
                        ],
                        selected: {_mode},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => _setMode(v.first),
                      ),
                    ),
                    if (_mode == 'vertical')
                      _controlGroup(
                        '浏览',
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('连续滚动')),
                            ButtonSegment(value: true, label: Text('逐页')),
                          ],
                          selected: {_snap},
                          showSelectedIcon: false,
                          onSelectionChanged: (v) => _setSnap(v.first),
                        ),
                      ),
                    if (_mode == 'horizontal')
                      _controlGroup(
                        '双页',
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('单页')),
                            ButtonSegment(value: true, label: Text('对开')),
                          ],
                          selected: {_doublePage},
                          showSelectedIcon: false,
                          onSelectionChanged: (v) => _setDoublePage(v.first),
                        ),
                      ),
                    _controlGroup(
                      '自动',
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('关')),
                          ButtonSegment(value: 3, label: Text('3秒')),
                          ButtonSegment(value: 5, label: Text('5秒')),
                          ButtonSegment(value: 10, label: Text('10秒')),
                          ButtonSegment(value: 30, label: Text('30秒')),
                        ],
                        selected: {_autoSeconds},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => _setAuto(v.first),
                      ),
                    ),
                    _controlGroup(
                      '秒数',
                      SizedBox(
                        width: 72,
                        child: _NumberInput(
                          hintText: '间隔秒',
                          onSubmit: (v) {
                            if (v >= 1 && v <= 3600) _setAuto(v);
                          },
                        ),
                      ),
                    ),
                    if (!_isPageMode)
                      SizedBox(
                        width: 250,
                        child: Row(
                          children: [
                            Text(
                              '翻屏 $_scrollPercent%',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Expanded(
                              child: Slider(
                                value: _scrollPercent.toDouble(),
                                min: 10,
                                max: 100,
                                divisions: 18,
                                label: '$_scrollPercent%',
                                onChanged: (v) =>
                                    setState(() => _scrollPercent = v.round()),
                                onChangeEnd: (v) => _savePref(
                                  'reader.manga.scrollPercent',
                                  '${v.round()}',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: _NumberInput(
                                hintText: '%',
                                onSubmit: (v) {
                                  if (v >= 10 && v <= 100) {
                                    setState(() => _scrollPercent = v);
                                    _savePref(
                                      'reader.manga.scrollPercent',
                                      '$v',
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.bookmark_border,
                        color: Colors.white70,
                        size: 20,
                      ),
                      label: const Text(
                        '书签',
                        style: TextStyle(color: Colors.white70),
                      ),
                      onPressed: () => _showBookmarksSheet(sources, local),
                    ),
                  ],
                ),
                if (!_isPageMode)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '翻屏距离按屏幕高度计算，仅影响侧边点按和自动翻屏；手指滑动保持跟手。',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

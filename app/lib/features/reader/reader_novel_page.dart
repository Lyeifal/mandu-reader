part of 'reader_page.dart';

// 小说阅读器（自 reader_page.dart 拆出，行为不变）。

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

  // 护眼自定义 / 定时切换 / 背景图（设置页「阅读设置」组维护）
  String _customBg = '#FCFCFA';
  String _customFg = '#2A2A2A';
  String _bgImage = ''; // 背景图副本绝对路径（桌面端可设）；空 = 纯色
  String _schedule = 'off'; // off | system | time
  String _scheduleNight = 'night';
  String _scheduleStart = '20:00';
  String _scheduleEnd = '07:00';
  String? _scheduledTheme; // 定时覆盖结果；null = 不覆盖手动选择
  Timer? _scheduleTimer;
  String _fontFamily = ''; // 自定义字体（fontFamilyFor 名）；空 = 系统默认
  String? _activeFontFamily; // 本次 build 生效的字体（已加载校验后）

  final _scroll = ScrollController();
  late final PageController _page = PageController();
  double _progress = 0; // 滚动模式进度 0..1
  int _currentPage = 0;

  // 进度持久化（同漫画侧：进阅读器恢复，退出落库 + 尽力推事件）
  bool _progressRestored = false;
  String _devName = 'dev';

  // dispose 里不能用 WidgetRef（Riverpod 抛 Bad state），挂载期缓存依赖。
  late final AppDatabase _db;
  BucketClient? _bucketClient;
  bool _depsCached = false;

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
    // 定时切换：进入阅读器后每分钟评估一次（_loadPrefs 也会立即评一次）
    _scheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _evaluateSchedule();
    });
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (max > 0) {
        setState(() => _progress = (_scroll.offset / max).clamp(0.0, 1.0));
      }
    });
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
    final customBg = await repo.get('reader.novel.customBg');
    final customFg = await repo.get('reader.novel.customFg');
    final schedule = await repo.get('reader.novel.themeSchedule');
    final night = await repo.get('reader.novel.themeScheduleNightPreset');
    final start = await repo.get('reader.novel.themeScheduleStart');
    final end = await repo.get('reader.novel.themeScheduleEnd');
    final bg = await repo.get('reader.novel.bgImage');
    final font = await repo.get('reader.novel.fontFamily');
    if (mounted) {
      setState(() {
        // 'custom' 不在 presets 表里，单独放行
        if (theme == 'custom' || _NovelTheme.presets.containsKey(theme)) {
          _theme = theme!;
        }
        _fontSize = (fontSize ?? 16).clamp(12, 32);
        _brightness = (brightness ?? 1.0).clamp(0.3, 1.0);
        if (paging == 'scroll') _paging = 'scroll';
        if (paging == 'page') _paging = 'page';
        _customBg = customBg ?? _customBg;
        _customFg = customFg ?? _customFg;
        if (schedule == 'off' || schedule == 'system' || schedule == 'time') {
          _schedule = schedule!;
        }
        if (_NovelTheme.presets.containsKey(night)) {
          _scheduleNight = night!;
        }
        if (parseHm(start ?? '') != null) _scheduleStart = start!;
        if (parseHm(end ?? '') != null) _scheduleEnd = end!;
        _fontFamily = font ?? '';
      });
      // 背景图：副本缺失（用户清了文件/换机）回退纯色并清设置，绝不 throw
      final bgPath = bg ?? '';
      if (bgPath.isNotEmpty && await File(bgPath).exists()) {
        setState(() => _bgImage = bgPath);
      } else if (bgPath.isNotEmpty) {
        await repo.set('reader.novel.bgImage', '');
      }
      _evaluateSchedule();
    }
  }

  /// 当前生效主题：定时覆盖 ?? 手动预设（custom 用自定义色，非法回退白昼）。
  _NovelTheme get _preset {
    final scheduled = _scheduledTheme;
    if (scheduled != null) {
      return _NovelTheme.presets[scheduled] ?? _NovelTheme.presets['night']!;
    }
    if (_theme == 'custom') {
      return _NovelTheme(
        parseHexColor(_customBg) ?? const Color(0xFFFCFCFA),
        parseHexColor(_customFg) ?? const Color(0xFF2A2A2A),
      );
    }
    return _NovelTheme.presets[_theme] ?? _NovelTheme.presets['day']!;
  }

  /// 定时切换评估（每分钟一次 + 进阅读器一次）。手动点选仍写 themePreset，
  /// 定时开启期间会被窗口覆盖，窗口外恢复手动选择。
  void _evaluateSchedule() {
    if (!mounted) return;
    final now = DateTime.now();
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final r = evaluateThemeSchedule(
      _schedule,
      _scheduleNight,
      _scheduleStart,
      _scheduleEnd,
      now.hour * 60 + now.minute,
      dark,
    );
    if (r != _scheduledTheme) setState(() => _scheduledTheme = r);
  }

  Future<void> _savePref(String key, String value) =>
      ref.read(settingsRepositoryProvider).set(key, value);

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    // 退出保存最终位置（本地 + 尽力推桶事件；失败只记日志）
    unawaited(
      saveProgressSafely(_db, _bucketClient, widget.work, {
        'para': _currentPara,
      }, dev: _devName),
    );
    _scroll.dispose();
    _page.dispose();
    super.dispose();
  }

  int get _currentPara {
    // 文本经 _parasOf 漏斗缓存（build 每帧刷新），dispose 期取缓存而非 ref。
    final text = _cachedText;
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
  /// 自定义字体的字宽启发式（1.0/0.55）不精确，widthFactor 留 5% 安全边。
  NovelPages _paginate(
    List<String> paragraphs,
    List<({String title, int para})> chapters,
    BoxConstraints c,
  ) {
    final chapterStarts = {for (final ch in chapters) ch.para};
    final key =
        '${paragraphs.length}:${paragraphs.firstOrNull}:${paragraphs.lastOrNull}'
        // 键含「字体是否已加载」：加载前后 widthFactor 不同，同键会复用错版分页
        ':$_fontSize:${c.maxWidth}x${c.maxHeight}:${_activeFontFamily != null ? _fontFamily : 'sys'}:${chapters.length}';
    if (_pages != null && _pagesKey == key) return _pages!;
    _pages = paginateNovel(
      paragraphs,
      contentWidth: (c.maxWidth - 40).clamp(50, 1 << 20).toDouble(),
      contentHeight: (c.maxHeight - 80).clamp(50, 1 << 20).toDouble(),
      fontSize: _fontSize,
      widthFactor: _activeFontFamily != null ? 0.95 : 1.0,
      chapterStarts: chapterStarts,
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
        ref.read(bucketClientProvider),
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
      appendReaderEventSafely(
        ref.read(bucketClientProvider),
        bookmarkDeleteEvent(dev: _devName, id: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = ref.watch(_novelTextProvider(widget.work));
    final chaptersFile = ref.watch(_chaptersFileProvider(widget.work));
    final bookmarks =
        ref.watch(_bookmarksProvider(widget.work.id)).value ??
        const <Bookmark>[];
    final preset = _preset;
    final fontLib = ref.watch(fontLibraryProvider).value ?? const <FontEntry>[];
    // 仅当字体已加载进引擎才注入 family，未就绪时回退系统字体（下一帧自动切换）
    _activeFontFamily =
        _fontFamily.isNotEmpty && fontLib.any((e) => e.family == _fontFamily)
        ? _fontFamily
        : null;

    return text.when(
      loading: () => Scaffold(
        backgroundColor: preset.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        // 报错页必须有回退口：下载中的书有占位行，点开必然走到这里，
        // 没返回键会被困在本页无法继续用 App
        appBar: AppBar(title: const Text('无法打开')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败: $e', textAlign: TextAlign.center),
                if (e.toString().contains('book.txt')) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '书籍文件尚未就绪：下载可能还没完成或已失败。\n'
                    '到任务面板查看进度/点重试，或返回书架稍后再试。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
          body: Container(
            // 背景图（桌面端可选设置）：Scaffold 底色垫底，图片铺满，
            // 亮度遮罩在更上层 Stack 叠加；副本缺失已在 _loadPrefs 回退清空
            decoration: _bgImage.isNotEmpty
                ? BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(File(_bgImage)),
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final zoneW = constraints.maxWidth * 0.25;
                final pages = _paginate(paragraphs, chapters, constraints);
                final chapterParas = {for (final ch in chapters) ch.para};
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
                                    for (
                                      var li = 0;
                                      li < pages.pages[page].length;
                                      li++
                                    )
                                      Builder(
                                        builder: (_) {
                                          final line = pages.pages[page][li];
                                          final isTitle =
                                              pages.titleMasks.length > page &&
                                              pages.titleMasks[page].contains(
                                                li,
                                              );
                                          // 固定行高 = 分页预算的行成本，保证整页不溢出；
                                          // 标题同盒渲染（字号+2、行高收紧到 1.4），
                                          // 视觉上与正文拉开层级，章首一眼可辨
                                          return SizedBox(
                                            height: _fontSize * 1.7 + 2,
                                            child: Text(
                                              line,
                                              style: TextStyle(
                                                fontSize:
                                                    (isTitle
                                                            ? _fontSize + 2
                                                            : _fontSize)
                                                        .toDouble(),
                                                height: isTitle ? 1.4 : 1.7,
                                                fontWeight: isTitle
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: preset.fg,
                                                fontFamily: _activeFontFamily,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                40,
                                20,
                                40,
                              ),
                              itemCount: paragraphs.length,
                              itemBuilder: (context, i) {
                                final isTitle = chapterParas.contains(i);
                                return Padding(
                                  padding: EdgeInsets.only(
                                    top: isTitle && i > 0 ? 16 : 0,
                                    bottom: 8,
                                  ),
                                  child: SelectableText(
                                    paragraphs[i],
                                    style: TextStyle(
                                      fontSize:
                                          (isTitle ? _fontSize + 2 : _fontSize)
                                              .toDouble(),
                                      height: 1.7,
                                      fontWeight: isTitle
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: preset.fg,
                                      fontFamily: _activeFontFamily,
                                    ),
                                  ),
                                );
                              },
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
                                Icon(
                                  Icons.bookmark,
                                  size: 14,
                                  color: preset.fg,
                                ),
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
                showSelectedIcon: false,
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
                  ButtonSegment(value: 'eyecare', label: Text('护眼')),
                  ButtonSegment(value: 'parchment', label: Text('羊皮纸')),
                  ButtonSegment(value: 'night', label: Text('夜间')),
                  ButtonSegment(value: 'custom', label: Text('自定义')),
                ],
                selected: {_theme},
                showSelectedIcon: false,
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
              Text('字体', style: TextStyle(color: preset.fg)),
              const SizedBox(width: 10),
              DropdownButton<String>(
                dropdownColor: preset.bg,
                style: TextStyle(color: preset.fg, fontSize: 14),
                value: _activeFontFamily ?? '',
                items: [
                  const DropdownMenuItem(value: '', child: Text('系统默认')),
                  for (final f
                      in ref.watch(fontLibraryProvider).value ??
                          const <FontEntry>[])
                    DropdownMenuItem(value: f.family, child: Text(f.fileName)),
                ],
                onChanged: (v) {
                  setState(() => _fontFamily = v ?? '');
                  _savePref('reader.novel.fontFamily', v ?? '');
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
              TextButton.icon(
                icon: const Icon(Icons.search),
                label: Text('搜索', style: TextStyle(color: preset.fg)),
                onPressed: () => _showSearchSheet(paragraphs, preset),
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

  void _showSearchSheet(List<String> paragraphs, _NovelTheme preset) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: preset.bg,
      builder: (context) => _NovelSearchSheet(
        paragraphs: paragraphs,
        bg: preset.bg,
        fg: preset.fg,
        onJump: (para) {
          Navigator.of(context).pop();
          _jumpToPara(para);
        },
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

/// 书内搜索弹层：输入防抖后内存子串扫描（设计文档 §9），
/// 结果列表高亮命中词，点击跳转到所在段。
class _NovelSearchSheet extends StatefulWidget {
  const _NovelSearchSheet({
    required this.paragraphs,
    required this.bg,
    required this.fg,
    required this.onJump,
  });

  final List<String> paragraphs;
  final Color bg;
  final Color fg;
  final ValueChanged<int> onJump;

  @override
  State<_NovelSearchSheet> createState() => _NovelSearchSheetState();
}

class _NovelSearchSheetState extends State<_NovelSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _hits = const [];
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _lastQuery = q;
        _hits = searchNovel(widget.paragraphs, q);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.fg;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                controller: _controller,
                onChanged: _onQueryChanged,
                style: TextStyle(color: fg),
                decoration: InputDecoration(
                  hintText: '书内搜索…',
                  hintStyle: TextStyle(color: fg.withValues(alpha: 0.5)),
                  prefixIcon: Icon(Icons.search, color: fg),
                  filled: true,
                  fillColor: fg.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _lastQuery.trim().isEmpty
                      ? '输入关键词，在本书全文中搜索'
                      : '$_lastQuery：${_hits.length} 个结果',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                itemCount: _hits.length,
                itemBuilder: (context, i) {
                  final hit = _hits[i];
                  final queryLen = _lastQuery.trim().length;
                  final at = hit.excerptHitAt.clamp(0, hit.excerpt.length);
                  final end = (at + queryLen).clamp(0, hit.excerpt.length);
                  return ListTile(
                    dense: true,
                    title: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(color: fg, fontSize: 14, height: 1.4),
                        children: [
                          TextSpan(text: hit.excerpt.substring(0, at)),
                          TextSpan(
                            text: hit.excerpt.substring(at, end),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              backgroundColor: fg.withValues(alpha: 0.3),
                            ),
                          ),
                          TextSpan(text: hit.excerpt.substring(end)),
                        ],
                      ),
                    ),
                    subtitle: Text(
                      '第 ${hit.para + 1} 段',
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => widget.onJump(hit.para),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

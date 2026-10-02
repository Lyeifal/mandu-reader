import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../downloader/cloud_compress.dart';
import '../downloader/compress_review.dart';
import '../downloader/display_image.dart';
import '../downloader/jm_download_dialog.dart';
import '../downloader/jm_pipeline.dart';
import '../downloader/jm_tasks.dart';
import '../jm/jm_browse.dart';
import '../providers.dart';
import '../settings/settings_page.dart';
import 'index_sync.dart';
import 'events_log.dart';
import 'shelf_add_dialog.dart';
import 'shelf_filter_panel.dart';
import 'shelf_query.dart';
import 'work_delete.dart';

/// 紧凑分段按钮样式：手机上顶栏不挤。
const _tabsCompactStyle = ButtonStyle(
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6)),
);

/// 书架页：漫画/小说页签 + 左侧筛选 + 右侧网格 + 底部翻页器。
class ShelfPage extends ConsumerStatefulWidget {
  const ShelfPage({super.key});

  static const path = '/shelf';

  /// 云端压缩需要本机 ffmpeg 可执行文件——Android 无法执行外部二进制
  /// （SELinux），按钮只在桌面端显示（设计文档 §14.2：手机下载保留原图，
  /// 由 PC 端兜底压缩）。
  static bool get cloudCompressSupported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  ConsumerState<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends ConsumerState<ShelfPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _syncing = false;
  bool _panelOpen = true;
  bool _panelInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_panelInit) {
      // 窄屏（手机）默认收起筛选栏，避免网格被压没
      _panelInit = true;
      _panelOpen = MediaQuery.sizeOf(context).width >= 600;
    }
  }

  /// 顶部页签：manga | jm | novel（jm 为应用内 JM 浏览，不占筛选类型）。
  String _tab = 'novel';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final filter = ref.read(shelfFilterProvider);
      if (filter.query != value) {
        ref
            .read(shelfFilterProvider.notifier)
            .apply(filter.copyWith(query: value));
        ref.read(shelfPageProvider.notifier).go(1);
        // 搜索词计入历史标签排序
        if (value.trim().isNotEmpty) pushRecentQuery(ref, value);
      }
    });
  }

  void _switchTab(String tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == 'jm') return;
    final filter = ref.read(shelfFilterProvider);
    if (filter.type != tab) {
      ref.read(shelfFilterProvider.notifier).apply(filter.copyWith(type: tab));
      ref.read(shelfPageProvider.notifier).go(1);
    }
  }

  Future<void> _sync() async {
    final client = ref.read(bucketClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('桶客户端不可用，请先在设置中配置并解锁')));
      return;
    }
    setState(() => _syncing = true);
    try {
      final report = await IndexSync(
        db: ref.read(appDatabaseProvider),
        client: client,
        localRootResolver: () =>
            resolveLocalRoot(ref.read(settingsRepositoryProvider)),
      ).sync();
      // 第二步：重放用户状态事件（进度/书签跨设备合并）。
      // 失败不阻塞同步结果——索引已入库，事件下次同步再补。
      try {
        await syncEventsFromBucket(
          db: ref.read(appDatabaseProvider),
          client: client,
        );
      } on Object catch (e) {
        debugPrint('events replay failed: $e');
      }
      // 同步可能改了库内容：清查询缓存并刷新列表/计数/筛选项
      ref.read(shelfWorksCacheProvider).clear();
      ref
        ..invalidate(shelfWorksProvider)
        ..invalidate(shelfTotalProvider)
        ..invalidate(shelfTagsProvider)
        ..invalidate(shelfStatusesProvider)
        ..invalidate(shelfAuthorsProvider);
      if (!mounted) return;
      final msg = report.upToDate
          ? '已是最新'
          : '同步 ${report.upserted} 本'
                '${report.badLines.isEmpty ? '' : '，跳过坏行 ${report.badLines.length}'}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('同步失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _addWork(String type) {
    showDialog<void>(
      context: context,
      builder: (context) => AddWorkDialog(initialType: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final works = ref.watch(shelfWorksProvider);
    final total = ref.watch(shelfTotalProvider).value ?? 0;
    final filter = ref.watch(shelfFilterProvider);
    final compressState = ref.watch(cloudCompressProvider);
    final type = _tab == 'jm'
        ? (filter.type.isEmpty ? 'manga' : filter.type)
        : _tab;
    var page = ref.watch(shelfPageProvider);
    final pageSize = ref.watch(shelfPageSizeProvider);
    final pages = math.max(1, (total + pageSize - 1) ~/ pageSize);
    if (page > pages) {
      // 数据变少（如同步后）页码超界，回落到末页
      page = pages;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(shelfPageProvider.notifier).go(pages);
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _panelOpen ? '收起筛选栏' : '展开筛选栏',
          icon: Icon(_panelOpen ? Icons.chevron_left : Icons.filter_list),
          onPressed: () => setState(() => _panelOpen = !_panelOpen),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            if (_compact)
              const Text('书架', style: TextStyle(fontSize: 14))
            else
              const Text('书架'),
            if (_compact)
              const SizedBox(width: 8)
            else
              const SizedBox(width: 12),
            _buildTabs(),
            if (!_compact) ...[
              const SizedBox(width: 12),
              if (_tab != 'jm') SizedBox(width: 260, child: _buildSearch()),
            ],
          ],
        ),
        actions: _compact
            ? [
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_vert),
                  onSelected: _onMenu,
                  itemBuilder: (context) => [
                    PopupMenuItem(enabled: false, child: Text('共 $total 部')),
                    const PopupMenuItem(value: 'add', child: Text('添加作品')),
                    const PopupMenuItem(value: 'jm', child: Text('JM 下载')),
                    const PopupMenuItem(value: 'tasks', child: Text('下载任务')),
                    PopupMenuItem(
                      value: 'sync',
                      enabled: !_syncing,
                      child: const Text('同步'),
                    ),
                    if (ShelfPage.cloudCompressSupported)
                      PopupMenuItem(
                        value: 'compress',
                        enabled: !compressState.running,
                        child: const Text('压缩云端漫画'),
                      ),
                    if (ShelfPage.cloudCompressSupported)
                      const PopupMenuItem(
                        value: 'review',
                        child: Text('审阅压缩（逐页决定）'),
                      ),
                    const PopupMenuItem(value: 'settings', child: Text('设置')),
                  ],
                ),
              ]
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: Text(
                      '共 $total 部',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '添加作品',
                  icon: const Icon(Icons.add),
                  onPressed: () => _addWork(type),
                ),
                IconButton(
                  tooltip: 'JM 下载',
                  icon: const Icon(Icons.cloud_download),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => const JmDownloadDialog(),
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final active = ref.watch(activeJmTaskCountProvider);
                    return Badge.count(
                      count: active,
                      isLabelVisible: active > 0,
                      child: IconButton(
                        tooltip: '下载任务',
                        icon: const Icon(Icons.downloading),
                        onPressed: () => JmTasksSheet.show(context),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: '同步',
                  icon: _syncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  onPressed: _syncing ? null : _sync,
                ),
                if (ShelfPage.cloudCompressSupported)
                  IconButton(
                    tooltip: '压缩云端漫画（把桶里未压缩的页面转 AVIF）',
                    icon: const Icon(Icons.compress),
                    onPressed: compressState.running ? null : _compressCloud,
                  ),
                if (ShelfPage.cloudCompressSupported)
                  IconButton(
                    tooltip: '审阅压缩：逐页对比原图与 AVIF，人工决定保留哪张',
                    icon: const Icon(Icons.compare_outlined),
                    onPressed: () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const CompressReviewDialog(),
                    ),
                  ),
                IconButton(
                  tooltip: '设置',
                  icon: const Icon(Icons.settings),
                  onPressed: () => context.go(SettingsPage.path),
                ),
              ],
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _panelOpen && _tab != 'jm' ? 232 : 0,
            child: _panelOpen && _tab != 'jm'
                ? const ShelfFilterPanel()
                : const SizedBox.shrink(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                if (_compact && _tab != 'jm')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                    child: _buildSearch(),
                  ),
                Expanded(
                  child: _tab == 'jm'
                      ? const JmBrowseView()
                      : Column(
                          children: [
                            if (compressState.running ||
                                compressState.report != null ||
                                compressState.error != null)
                              _CompressBanner(
                                state: compressState,
                                onRetry: _compressCloud,
                                onClose: () => ref
                                    .read(cloudCompressProvider.notifier)
                                    .clear(),
                              ),
                            Expanded(
                              child: works.when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, _) =>
                                    Center(child: Text('加载失败: $e')),
                                data: (list) => list.isEmpty
                                    ? _EmptyHint(
                                        filtered:
                                            !filter.isDefault || total > 0,
                                      )
                                    : GridView.builder(
                                        padding: const EdgeInsets.all(16),
                                        gridDelegate:
                                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 170,
                                              childAspectRatio: 0.56,
                                              mainAxisSpacing: 12,
                                              crossAxisSpacing: 12,
                                            ),
                                        itemCount: list.length,
                                        itemBuilder: (context, i) => _WorkCard(
                                          work: list[i],
                                          onTap: () => _showWorkInfo(list[i]),
                                        ),
                                      ),
                              ),
                            ),
                            if (total > 0)
                              _PagerBar(
                                page: page,
                                pages: pages,
                                total: total,
                                pageSize: pageSize,
                                onGoto: (p) =>
                                    ref.read(shelfPageProvider.notifier).go(p),
                                onSize: (n) {
                                  ref
                                      .read(shelfPageSizeProvider.notifier)
                                      .set(n);
                                  ref.read(shelfPageProvider.notifier).go(1);
                                },
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _compact => MediaQuery.sizeOf(context).width < 600;

  Widget _buildTabs() => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: 'manga', label: Text('漫画')),
      ButtonSegment(value: 'jm', label: Text('JM漫画')),
      ButtonSegment(value: 'novel', label: Text('小说')),
    ],
    selected: {_tab},
    // M3 选中段默认带对勾图标，且各段等宽：「JM漫画」+对勾会把三段一起
    // 拉宽，手机端顶栏直接横向溢出（黑黄条纹报错）。选中态靠底色区分即可。
    showSelectedIcon: false,
    style: _compact ? _tabsCompactStyle : null,
    onSelectionChanged: (v) => _switchTab(v.first),
  );

  Widget _buildSearch() => TextField(
    controller: _search,
    decoration: const InputDecoration(
      hintText: '搜索标题 / 作者 / 系列',
      prefixIcon: Icon(Icons.search),
      border: OutlineInputBorder(),
      isDense: true,
    ),
    onChanged: _onSearch,
  );

  void _onMenu(String value) {
    final filter = ref.read(shelfFilterProvider);
    final type = _tab == 'jm'
        ? (filter.type.isEmpty ? 'manga' : filter.type)
        : _tab;
    switch (value) {
      case 'add':
        _addWork(type);
      case 'jm':
        showDialog<void>(
          context: context,
          builder: (context) => const JmDownloadDialog(),
        );
      case 'tasks':
        JmTasksSheet.show(context);
      case 'sync':
        if (!_syncing) _sync();
      case 'compress':
        _compressCloud();
      case 'review':
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const CompressReviewDialog(),
        );
      case 'settings':
        context.go(SettingsPage.path);
    }
  }

  /// 压缩云端漫画：任务进后台 notifier，进度/结果/重试由书架页横幅常驻展示。
  Future<void> _compressCloud() async {
    final client = ref.read(bucketClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('桶客户端不可用，请先在设置中配置并解锁')));
      return;
    }
    final ffmpeg =
        (await ref.read(settingsRepositoryProvider).get('downloader.ffmpeg'))
            ?.trim() ??
        '';
    if (!mounted) return;
    if (ffmpeg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置页填写本机 ffmpeg 路径（仅桌面端可用）')),
      );
      return;
    }
    await ref
        .read(cloudCompressProvider.notifier)
        .start(
          db: ref.read(appDatabaseProvider),
          client: client,
          ffmpegPath: ffmpeg,
        );
    // 压缩可能换了封面/索引行：刷列表
    ref.read(shelfWorksCacheProvider).clear();
    ref.invalidate(shelfWorksProvider);
  }

  void _showWorkInfo(Work work) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _WorkInfoSheet(work: work),
    );
  }
}

class _EmptyHint extends ConsumerWidget {
  const _EmptyHint({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(filtered ? '没有匹配的作品' : '书架为空，点右上角同步或添加作品'),
          if (filtered) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                // 只清条件、保留当前页签类型，避免漫画页清完跳出小说
                final type = ref.read(shelfFilterProvider).type;
                ref
                    .read(shelfFilterProvider.notifier)
                    .apply(ShelfFilter.empty.copyWith(type: type));
                ref.read(shelfPageProvider.notifier).go(1);
              },
              child: const Text('清空筛选'),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkCard extends ConsumerWidget {
  const _WorkCard({required this.work, required this.onTap});

  final Work work;
  final VoidCallback onTap;

  static const _statusColors = {
    'ongoing': Color(0xFF4CAF7D),
    'completed': Color(0xFF4C8DFF),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverColor = _hashColor(work.title);
    final coverSource = ref.watch(coverSourceProvider(work)).value;
    final statusColor = _statusColors[work.status];

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: coverColor,
                alignment: Alignment.center,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (coverSource != null)
                      coverSource.$2
                          ? displayUrlImage(
                              coverSource.$1,
                              fit: BoxFit.cover,
                              fallback: _coverPlaceholder(work),
                            )
                          : displayLocalImage(
                              coverSource.$1,
                              fit: BoxFit.cover,
                              fallback: _coverPlaceholder(work),
                            )
                    else
                      _coverPlaceholder(work),
                    if (statusColor != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black45, width: 1),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _badge(work.type == 'manga' ? '漫' : '文'),
                    ),
                    if (work.localOnly)
                      const Positioned(
                        top: 6,
                        left: 6,
                        child: Icon(
                          Icons.smartphone,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                  ),
                  if (work.author.isNotEmpty)
                    Text(
                      work.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _coverPlaceholder(Work work) => Center(
    child: Text(
      work.title.isEmpty ? '?' : work.title.substring(0, 1),
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: Colors.white54,
      ),
    ),
  );

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  static Color _hashColor(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return HSLColor.fromAHSL(
      1,
      (h % 360).toDouble(),
      0.32,
      0.26 + (h % 10) / 100,
    ).toColor();
  }
}

/// 底部翻页器：‹ 页码（±2 窗口折叠）› + 每页条数。
class _PagerBar extends StatelessWidget {
  const _PagerBar({
    required this.page,
    required this.pages,
    required this.total,
    required this.pageSize,
    required this.onGoto,
    required this.onSize,
  });

  final int page;
  final int pages;
  final int total;
  final int pageSize;
  final ValueChanged<int> onGoto;
  final ValueChanged<int> onSize;

  List<Object> _pageList() {
    const win = 2;
    final out = <Object>[];
    var prev = 0;
    for (var p = 1; p <= pages; p++) {
      if (p == 1 || p == pages || (p - page).abs() <= win) {
        if (prev != 0 && p - prev > 1) out.add('…');
        out.add(p);
        prev = p;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 1 ? () => onGoto(page - 1) : null,
          ),
          for (final p in _pageList())
            p == '…'
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: p == page
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: null,
                            child: Text('$p'),
                          )
                        : TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => onGoto(p as int),
                            child: Text('$p'),
                          ),
                  ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: page < pages ? () => onGoto(page + 1) : null,
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: pageSize,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 24, child: Text('24 /页')),
              DropdownMenuItem(value: 48, child: Text('48 /页')),
              DropdownMenuItem(value: 96, child: Text('96 /页')),
            ],
            onChanged: (v) {
              if (v != null) onSize(v);
            },
          ),
        ],
      ),
    );
  }
}

/// 作品信息底部弹层；点作者名可按作者筛选。
class _WorkInfoSheet extends ConsumerWidget {
  const _WorkInfoSheet({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<Widget> rows = [
      if (work.author.isNotEmpty)
        _row(
          '作者',
          work.author,
          onTap: () {
            ref
                .read(shelfFilterProvider.notifier)
                .apply(
                  ref.read(shelfFilterProvider).copyWith(author: work.author),
                );
            ref.read(shelfPageProvider.notifier).go(1);
            Navigator.of(context).pop();
          },
        ),
      if (work.series.isNotEmpty)
        _row(
          '系列',
          work.volume != null
              ? '${work.series} 第 ${work.volume} 卷'
              : work.series,
        ),
      _row('类型', work.type == 'manga' ? '漫画' : '小说'),
      _row('状态', statusLabel(work.status)),
      if (work.publishedAt != null) _row('发布', work.publishedAt!),
      if (work.completedAt != null) _row('完结', work.completedAt!),
      if (work.pages != null) _row('页数', '${work.pages}'),
      if (work.totalChars != null) _row('字数', '${work.totalChars}'),
      if (work.lastUpdated != null) _row('更新', work.lastUpdated!),
      _row('来源', work.origin),
      if (work.localOnly) _row('存储', '仅本设备'),
    ];

    List<String> tags = const [];
    try {
      tags = (jsonDecode(work.tags) as List).map((e) => e.toString()).toList();
    } on Object {
      // 坏 JSON 视为无标签
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(work.title, style: Theme.of(context).textTheme.titleLarge),
          if (work.titleJp.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              work.titleJp,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
          const SizedBox(height: 16),
          for (final r in rows) ...[r, const SizedBox(height: 6)],
          const SizedBox(height: 8),
          // 标签全量展示：点击按标签筛选；+ 号新增标签到本书
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tags)
                ActionChip(
                  label: Text(t),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref
                        .read(shelfFilterProvider.notifier)
                        .apply(
                          ref
                              .read(shelfFilterProvider)
                              .copyWith(tagModes: {t: TagMode.or}),
                        );
                    ref.read(shelfPageProvider.notifier).go(1);
                    pushRecentTag(ref, t);
                    Navigator.of(context).pop();
                  },
                ),
              ActionChip(
                label: const Icon(Icons.add, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _addTag(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.menu_book),
                  label: const Text('阅读'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/reader', extra: work);
                  },
                ),
              ),
              if (work.localOnly) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('上传到书架'),
                    onPressed: () => _upload(context, ref),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Theme.of(context).colorScheme.outline,
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除本地'),
                onPressed: () => _deleteLocal(context, ref),
              ),
              if (!work.localOnly) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Theme.of(context).colorScheme.outline,
                  ),
                  icon: const Icon(Icons.cloud_off_outlined, size: 18),
                  label: const Text('删除云端'),
                  onPressed: () => _deleteCloud(context, ref),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 删除本设备文件/阅读缓存；书架记录保留。
  Future<void> _deleteLocal(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除本地文件'),
        content: Text(
          work.localOnly
              ? '本书是仅本设备作品，将删除本地文件并移除书架记录，无法恢复。确定删除？'
              : '将删除本设备的本地文件与阅读缓存；作品仍在云端，打开时会重新下载。确定删除？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteLocalWorkFiles(ref, work);
      ref.invalidate(coverSourceProvider(work));
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已删除本地文件')));
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  /// 删除云端对象 + 移出同步索引；本设备文件保留（无本地则删书架记录）。
  Future<void> _deleteCloud(BuildContext context, WidgetRef ref) async {
    final hasLocal = work.localOnly;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除云端副本'),
        content: Text(
          hasLocal
              ? '将从云端删除本书全部文件并移出同步索引，本设备文件保留（转为仅本设备）。确定删除？'
              : '本设备没有本地副本，云端删除后将无法恢复。确定删除？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('正在删除云端副本…')));
    try {
      await deleteWorkFromCloud(ref, work);
      ref.read(shelfWorksCacheProvider).clear();
      ref
        ..invalidate(shelfWorksProvider)
        ..invalidate(shelfTotalProvider)
        ..invalidate(shelfTagsProvider)
        ..invalidate(shelfStatusesProvider)
        ..invalidate(shelfAuthorsProvider)
        ..invalidate(coverSourceProvider(work));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已删除云端副本')));
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  /// 给本书添加新标签（逗号分隔可多填）。
  Future<void> _addTag(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '多个标签用逗号分隔',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => Navigator.of(context).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    final input = controller.text.trim();
    if (added != true || input.isEmpty || !context.mounted) return;
    var current = <String>[];
    try {
      current = (jsonDecode(work.tags) as List)
          .map((e) => e.toString())
          .toList();
    } on Object {
      // 坏 JSON 视为无标签
    }
    final merged = <String>{
      ...current,
      ...input
          .split(RegExp(r'[,，、\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty),
    }.toList();
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.works)..where((t) => t.id.equals(work.id))).write(
      WorksCompanion(tags: Value(jsonEncode(merged))),
    );
    ref
      ..invalidate(shelfWorksProvider)
      ..invalidate(shelfTagsProvider);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已添加标签')));
    }
  }

  /// 上传归档（设计文档 §8.3）：本地页面传桶 + 追加索引 + 行转非本地。
  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final client = ref.read(bucketClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('桶客户端不可用：请先在设置中配置并解锁')));
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('开始上传…')));
    try {
      await JmPipeline(
        localRoot: await resolveLocalRoot(ref.read(settingsRepositoryProvider)),
      ).upload(
        db: ref.read(appDatabaseProvider),
        client: client,
        work: work,
        onProgress: (_) {},
      );
      ref.read(shelfWorksCacheProvider).clear();
      ref
        ..invalidate(shelfWorksProvider)
        ..invalidate(shelfTotalProvider)
        ..invalidate(shelfTagsProvider)
        ..invalidate(shelfStatusesProvider)
        ..invalidate(shelfAuthorsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('《${work.title}》已上传归档')));
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('上传失败: $e')));
      }
    }
  }

  Widget _row(String label, String value, {VoidCallback? onTap}) {
    final child = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: onTap != null
              ? Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.lightBlue,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                )
              : Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

/// 云端压缩常驻横幅：进行中转圈+阶段文案；结束给统计；失败给原因。
/// 失败项仍是桶里的非 AVIF 原图，「重试」重跑只处理它们（已 AVIF 自动跳过）。
class _CompressBanner extends StatelessWidget {
  const _CompressBanner({
    required this.state,
    required this.onRetry,
    required this.onClose,
  });

  final CloudCompressState state;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = state.report;
    final text = state.running
        ? '正在压缩云端漫画：${state.phase}'
        : state.error != null
        ? '压缩失败：${state.error}'
        : '压缩完成：新压 ${report!.compressed} 页，保留原图 ${report.keptOriginal} 页，'
              '无需处理 ${report.allAvif} 部'
              '${report.failed > 0 ? '，失败 ${report.failed} 项（可重试）' : ''}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          if (state.running)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              state.error != null ? Icons.error_outline : Icons.check_circle,
              size: 18,
              color: state.error != null
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (!state.running) ...[
            TextButton(onPressed: onRetry, child: const Text('重试')),
            IconButton(
              tooltip: '关闭',
              icon: const Icon(Icons.close, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ],
        ],
      ),
    );
  }
}

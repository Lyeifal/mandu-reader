/// 书源书籍详情 bottom sheet：详情 → 全量目录 → 选章范围 → 下载到书架。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../downloader/jm_tasks.dart';
import '../source_book.dart';
import '../source_models.dart';
import '../source_pipeline.dart';
import '../source_providers.dart';
import '../source_tasks.dart';
import '../source_toc.dart';
import '../source_selector.dart';

class SourceDetailSheet extends ConsumerStatefulWidget {
  const SourceDetailSheet({
    super.key,
    required this.sourceId,
    required this.bookUrl,
    this.preview,
  });

  final String sourceId;
  final String bookUrl;
  final SourceSearchResult? preview;

  static Future<void> show(
    BuildContext context, {
    required String sourceId,
    required String bookUrl,
    SourceSearchResult? preview,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SourceDetailSheet(
      sourceId: sourceId,
      bookUrl: bookUrl,
      preview: preview,
    ),
  );

  @override
  ConsumerState<SourceDetailSheet> createState() => _SourceDetailSheetState();
}

class _SourceDetailSheetState extends ConsumerState<SourceDetailSheet> {
  SourceBookInfo? _book;
  List<SourceChapter>? _toc;
  String? _error;
  bool _downloading = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = ref.read(allSourcesProvider).value ?? const [];
    final rule = findSource(rules, widget.sourceId);
    if (rule == null) {
      setState(() => _error = '书源不存在');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final http = await buildSourceHttp(ref.read, rule);
      final engine = SelectorEngine();
      final book = await SourceBook(
        rule,
        http,
        engine,
      ).parse(widget.bookUrl).timeout(const Duration(seconds: 40));
      if (!mounted) return;
      setState(() => _book = book);
      final toc = await SourceToc(
        rule,
        http,
        engine,
      ).parseAll(widget.bookUrl).timeout(const Duration(seconds: 60));
      if (!mounted) return;
      setState(() => _toc = toc);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().split('\n').first);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 下载按钮：下载中 → 直达任务面板；已完成 → 禁用；否则选范围下单。
  Future<void> _downloadPressed(NovelTask? task) async {
    switch (task?.status) {
      case NovelTaskStatus.downloading:
        await JmTasksSheet.show(context);
      case NovelTaskStatus.done:
        break; // 已在书架
      default:
        await _pickRange();
    }
  }

  Future<void> _download(List<SourceChapter> selected) async {
    final book = _book;
    if (book == null || selected.isEmpty || _downloading) return;
    setState(() => _downloading = true);
    final snap = NovelSnapshot(
      sourceId: widget.sourceId,
      bookUrl: book.url,
      bookName: book.bookName,
      author: book.author,
      status: book.status,
      coverUrl: book.coverUrl,
      chapters: selected,
    );
    // 先抓 ScaffoldMessenger：pop 之后 context 即死（AGENTS.md UI 坑 #1）
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context).pop();
    await startNovelDownload(container, snapshot: snap);
    messenger.showSnackBar(
      SnackBar(
        content: Text('《${book.bookName}》已加入下载任务（共 ${selected.length} 章）'),
      ),
    );
  }

  Future<void> _pickRange() async {
    final toc = _toc;
    if (toc == null || toc.isEmpty) return;
    final n = toc.length;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('最新 50 章'),
              subtitle: Text('第 ${(n - 50).clamp(1, n)}–$n 章'),
              onTap: () => Navigator.of(context).pop('latest50'),
            ),
            ListTile(
              title: const Text('全本'),
              subtitle: Text('共 $n 章'),
              onTap: () => Navigator.of(context).pop('all'),
            ),
            ListTile(
              title: const Text('自选区间'),
              subtitle: const Text('输入起止章号'),
              onTap: () => Navigator.of(context).pop('range'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    List<SourceChapter> selected;
    switch (choice) {
      case 'latest50':
        selected = n <= 50 ? toc : toc.sublist(n - 50);
      case 'all':
        selected = toc;
      default:
        final range = await _askRange(n);
        if (range == null) return;
        selected = toc.sublist(range.$1 - 1, range.$2);
    }
    await _download(selected);
  }

  Future<(int, int)?> _askRange(int total) async {
    final start = TextEditingController();
    final end = TextEditingController();
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('章节区间'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: start,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '起'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: end,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '止'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final a = int.tryParse(start.text.trim()) ?? 1;
              var b = int.tryParse(end.text.trim()) ?? total;
              if (a < 1 || b > total || a > b) return;
              b = b.clamp(a, total);
              Navigator.of(context).pop((a, b));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.preview;
    final book = _book;
    // 同一本书的已有下载任务（防重复下单 + 进度直达）
    final bookUrl = book?.url ?? widget.bookUrl;
    final task = ref
        .watch(novelTasksProvider)
        .where((t) => t.workId == novelWorkId(widget.sourceId, bookUrl))
        .firstOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book?.bookName ?? preview?.bookName ?? '加载中…',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              [
                book?.author ?? preview?.author ?? '',
                if (book?.status.isNotEmpty == true) book!.status,
                if (book?.lastUpdateTime.isNotEmpty == true)
                  '更新 ${book!.lastUpdateTime}',
                if (book?.latestChapter.isNotEmpty == true)
                  '更至 ${book!.latestChapter}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (book?.intro.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                book!.intro,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ] else if (_toc == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(
                '共 ${_toc!.length} 章',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _downloading ? null : () => _downloadPressed(task),
                  icon: const Icon(Icons.download),
                  label: Text(switch (task?.status) {
                    NovelTaskStatus.downloading => '下载中（点按看进度）',
                    NovelTaskStatus.done => '已在书架',
                    _ => _downloading ? '已加入任务…' : '下载到书架',
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

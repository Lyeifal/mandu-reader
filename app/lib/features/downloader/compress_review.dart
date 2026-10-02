import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/retry.dart';
import '../../data/db/app_database.dart';
import '../bucket/bucket_client.dart';
import '../bucket/path_helper.dart';
import '../library/shelf_query.dart';
import '../providers.dart';
import 'avif_transcoder.dart';
import 'cloud_compress.dart' show pageKeysOf, rewriteWorkIndex;
import 'display_image.dart';
import 'review_models.dart';

/// 压缩人工审阅：逐页对比「原图 vs 本地转码的 AVIF 候选」，由用户决定保留哪张。
///
/// 两种对比模式（顶栏切换）：
/// - 并排：左右两张图，图底半透明横条标体积
/// - 竖线：鼠标移动分割线，左右分别显示压缩前/后；下方同时显示体积
///
/// 决定立即生效：用 AVIF → 传桶 + 删原图；保留原图 → 丢弃候选。
/// 审阅是增量安全的——中途关闭已生效的决定都在桶里，重开会跳过已压页面。
class CompressReviewDialog extends ConsumerStatefulWidget {
  const CompressReviewDialog({super.key});

  @override
  ConsumerState<CompressReviewDialog> createState() =>
      _CompressReviewDialogState();
}

class _CompressReviewDialogState extends ConsumerState<CompressReviewDialog> {
  // 队列：云端漫画逐本展开，作品内逐页推进
  List<Work> _cloudWorks = const [];
  final List<String> _pending = [];
  Work? _work;
  String _dir = '';
  int _workIdx = 0;
  int _pageIdx = 0;
  int _decided = 0;
  final _touched = <String>{};

  // 当前页
  ReviewItem? _item;
  bool _loading = true;
  bool _done = false;
  String? _error; // 全局错误（ffmpeg 不可用/书架为空）
  String? _pageError; // 单页错误（下载/转码失败，可跳过）

  String _mode = 'side'; // side | wipe
  double _split = 0.5;

  AvifTranscoder? _transcoder;
  Directory? _tmp;
  var _seq = 0;

  AppDatabase get _db => ref.read(appDatabaseProvider);

  BucketClient get _client => ref.read(bucketClientProvider)!;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ffmpeg =
          (await ref.read(settingsRepositoryProvider).get('downloader.ffmpeg'))
              ?.trim() ??
          '';
      _transcoder = AvifTranscoder(ffmpegPath: ffmpeg);
      if (!await _transcoder!.available()) {
        throw StateError('ffmpeg 不可用，请先在设置页填写本机 ffmpeg 路径');
      }
      _tmp = Directory(
        p.join((await getTemporaryDirectory()).path, 'compress_review'),
      );
      await _tmp!.create(recursive: true);
      final rows = await (_db.select(
        _db.works,
      )..where((t) => t.type.equals('manga'))).get();
      _cloudWorks = rows
          .where((w) => !w.localOnly && w.cover != null && w.cover!.isNotEmpty)
          .toList();
      if (_cloudWorks.isEmpty) {
        throw StateError('书架里没有云端漫画可审');
      }
      await _advance();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('StateError: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    final tmp = _tmp;
    if (tmp != null && tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
    super.dispose();
  }

  /// 推进到下一个待审页：跨作品时先收尾当前作品（索引/封面回写）。
  Future<void> _advance() async {
    _pageIdx++;
    while (_work == null || _pageIdx >= _pending.length) {
      if (_work != null) {
        final w = _work!;
        _work = null;
        await _finalizeWork(w);
      }
      // 找到下一本还有待审页的作品
      var loaded = false;
      while (_workIdx < _cloudWorks.length) {
        final w = _cloudWorks[_workIdx];
        _workIdx++;
        try {
          final dir = p.dirname(LibraryPaths.normalizeKey(w.cover!));
          final keys = await withRetry(() => _client.listKeys(dir, max: 5000));
          final pending = pendingPageKeys(keys);
          if (pending.isNotEmpty) {
            _work = w;
            _dir = dir;
            _pending
              ..clear()
              ..addAll(pending);
            _pageIdx = 0;
            loaded = true;
            break;
          }
        } on Object {
          // 列目录失败：跳过这本
        }
      }
      if (!loaded) {
        if (mounted) {
          setState(() {
            _loading = false;
            _done = true;
          });
          ref.invalidate(shelfWorksProvider);
        }
        return;
      }
    }
    await _prepareCurrent();
  }

  /// 下载当前页原图 + 本地转 AVIF 候选。
  Future<void> _prepareCurrent() async {
    setState(() {
      _loading = true;
      _pageError = null;
    });
    final key = _pending[_pageIdx];
    final src = File(p.join(_tmp!.path, 'i$_seq${p.basename(key)}'));
    final out = File(p.join(_tmp!.path, 'o$_seq.avif'));
    _seq++;
    try {
      await withRetry(() async {
        await src.writeAsBytes(await _client.getAll(key));
      });
      if (!await _transcoder!.transcode(src.path, out.path)) {
        throw StateError('ffmpeg 未产出 AVIF');
      }
      _item = ReviewItem(
        target: ReviewTarget(key: key, isFirstPage: key == _pending.first),
        originalPath: src.path,
        avifPath: out.path,
        originalBytes: await src.length(),
        avifBytes: await out.length(),
      );
    } on Object catch (e) {
      _item = null;
      _pageError = e.toString().replaceFirst('StateError: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteTemps(ReviewItem item) async {
    for (final f in [File(item.originalPath), File(item.avifPath)]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// 应用决定并推进。失败（如传桶断网）留在当前页重试，不丢进度。
  Future<void> _decide(ReviewDecision d) async {
    final item = _item;
    if (item == null || _work == null) return;
    try {
      if (d == ReviewDecision.keepAvif) {
        await withRetry(() async {
          await _client.put(
            p.setExtension(item.target.key, '.avif'),
            await File(item.avifPath).readAsBytes(),
          );
          await _client.delete(item.target.key);
        });
        _touched.add(_work!.id);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _pageError = '应用决定失败：$e（可重试或跳过）');
      }
      return;
    }
    await _deleteTemps(item);
    _decided++;
    await _advance();
  }

  /// 当前作品剩余页全部保留原图（批量逃生口）。
  Future<void> _keepRestOriginal() async {
    final item = _item;
    if (item != null) {
      await _deleteTemps(item);
      _decided++;
    }
    _decided += _pending.length - _pageIdx - 1;
    _pageIdx = _pending.length;
    await _advance();
  }

  /// 作品审完：重列目录，回写索引行（compressed 标记）与派生封面。
  Future<void> _finalizeWork(Work w) async {
    if (!_touched.contains(w.id)) return;
    try {
      final keys = await withRetry(() => _client.listKeys(_dir, max: 5000));
      final pages = pageKeysOf(keys);
      final stillRaw = pages.where((k) => !k.endsWith('.avif')).length;
      final coverNorm = LibraryPaths.normalizeKey(w.cover!);
      var cover = coverNorm;
      final firstExt = pages.isEmpty
          ? ''
          : p.extension(pages.first).toLowerCase();
      final coverDerived = coverNorm == '$_dir/cover$firstExt';
      if (coverDerived && pages.isNotEmpty && pages.first.endsWith('.avif')) {
        final coverAvif = '$_dir/cover.avif';
        await withRetry(() async {
          await _client.put(coverAvif, await _client.getAll(pages.first));
          if (coverNorm != coverAvif) await _client.delete(coverNorm);
        });
        cover = coverAvif;
      }
      await rewriteWorkIndex(_client, w, pages.length, cover, stillRaw == 0);
      await (_db.update(_db.works)..where((t) => t.id.equals(w.id))).write(
        WorksCompanion(cover: Value(cover)),
      );
    } on Object catch (e) {
      debugPrint('review finalize ${w.id} failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 1120,
        height: 780,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.compare,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('压缩审阅', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'side',
                        icon: Icon(Icons.view_column, size: 16),
                        label: Text('并排'),
                      ),
                      ButtonSegment(
                        value: 'wipe',
                        icon: Icon(Icons.swap_horizontal_circle, size: 16),
                        label: Text('竖线对比'),
                      ),
                    ],
                    selected: {_mode},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onSelectionChanged: (v) => setState(() => _mode = v.first),
                  ),
                  const Spacer(),
                  Text(
                    _work == null
                        ? (_done ? '审阅完成 · 已决定 $_decided 页' : '')
                        : '《${_work!.title}》 第 ${_pageIdx + 1}/${_pending.length} 页 · 已决定 $_decided 页',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭（已生效的决定已写入桶）',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _body(theme)),
            const Divider(height: 1),
            _actions(theme),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_error != null) {
      return Center(child: Text('无法开始审阅：$_error'));
    }
    if (_done) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt, size: 48),
            const SizedBox(height: 12),
            Text('审阅完成，共决定 $_decided 页'),
            const SizedBox(height: 8),
            Text(
              '选择「跳过」的页面下次审阅还会出现',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }
    if (_loading && _item == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('下载并转码本页…'),
          ],
        ),
      );
    }
    if (_pageError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_pageError!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: _prepareCurrent,
                  child: const Text('重试本页'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _decide(ReviewDecision.skip),
                  child: const Text('跳过本页'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final item = _item!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _mode == 'side' ? _sideBySide(item) : _wipe(item),
    );
  }

  /// 并排模式：左右各一张，图底半透明横条标体积。
  Widget _sideBySide(ReviewItem item) {
    return Row(
      children: [
        Expanded(
          child: _labeledImage(
            item.originalPath,
            '原图 · ${formatSize(item.originalBytes)}',
          ),
        ),
        const SizedBox(width: 2),
        Container(width: 2, color: Theme.of(context).dividerColor),
        const SizedBox(width: 2),
        Expanded(
          child: _labeledImage(
            item.avifPath,
            'AVIF · ${formatSize(item.avifBytes)}（省 ${(item.saving * 100).round()}%）',
          ),
        ),
      ],
    );
  }

  Widget _labeledImage(String path, String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: displayLocalImage(path, fit: BoxFit.contain),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 竖线对比：底层 AVIF（右），顶层原图只露分割线以左；鼠标/拖动移动分割线。
  Widget _wipe(ReviewItem item) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        void move(double dx) => setState(() => _split = clampSplit(dx / w));
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: displayLocalImage(item.avifPath, fit: BoxFit.contain),
              ),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _split,
                  child: ColoredBox(
                    color: Colors.black,
                    child: displayLocalImage(
                      item.originalPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // 分割线 + 手柄
              Positioned(
                left: _split * w - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),
              Positioned(
                left: _split * w - 14,
                top: 0,
                bottom: 0,
                child: const Center(
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.unfold_more,
                      size: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              // 鼠标悬浮跟随 + 拖动
              MouseRegion(
                onHover: (e) => move(e.localPosition.dx),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (e) => move(e.localPosition.dx),
                  onTapDown: (e) => move(e.localPosition.dx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actions(ThemeData theme) {
    final item = _item;
    final busy = _loading || item == null || _done || _error != null;
    final sizeText = item == null
        ? ''
        : '原图 ${formatSize(item.originalBytes)} ｜ AVIF ${formatSize(item.avifBytes)}'
              '（省 ${(item.saving * 100).round()}%）';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          if (_mode == 'wipe' && item != null)
            Text(sizeText, style: theme.textTheme.bodySmall),
          const Spacer(),
          if (_work != null && _pending.length - _pageIdx > 3)
            TextButton(
              onPressed: busy ? null : _keepRestOriginal,
              child: Text('本作品剩余 ${_pending.length - _pageIdx} 页全保留原图'),
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.image, size: 18),
            onPressed: busy ? null : () => _decide(ReviewDecision.keepOriginal),
            label: const Text('保留原图'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.compress, size: 18),
            onPressed: busy ? null : () => _decide(ReviewDecision.keepAvif),
            label: const Text('使用 AVIF'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy ? null : () => _decide(ReviewDecision.skip),
            child: const Text('跳过'),
          ),
        ],
      ),
    );
  }
}

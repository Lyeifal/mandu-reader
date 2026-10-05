import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../library/cache_prune.dart';
import '../library/local_sweep.dart';
import '../source/source_tasks.dart';
import '../library/shelf_query.dart';
import '../library/upload_tasks.dart';
import '../providers.dart';
import 'avif_transcoder.dart';
import 'jm_pipeline.dart';

final _log = Logger('JmTasks');

enum JmTaskStatus { downloading, compressing, done, failed }

/// 后台下载任务。持久化到 drift jm_tasks 表：进程被杀/闪退后启动恢复
/// 列表，进行中的任务自动续跑（见 [_JmTasksNotifier._restore]）。
class JmTask {
  const JmTask({
    required this.albumId,
    required this.title,
    required this.status,
    required this.ffmpegPath,
    required this.proxy,
    this.phase = '',
    this.pages,
    this.keptOriginal,
    this.error,
  });

  final String albumId;
  final String title;
  final JmTaskStatus status;

  /// 当前阶段描述（下载中/压缩 x/y/…）。
  final String phase;

  /// 结果：总页数与被保留的原图页数（仅 done 时有值）。
  final int? pages;
  final int? keptOriginal;

  final String? error;

  /// 启动时的配置快照（重试/续跑用）。
  final String ffmpegPath;
  final String proxy;

  JmTask copyWith({
    String? title,
    JmTaskStatus? status,
    String? phase,
    int? pages,
    int? keptOriginal,
    String? error,
    bool clearError = false,
  }) => JmTask(
    albumId: albumId,
    title: title ?? this.title,
    status: status ?? this.status,
    phase: phase ?? this.phase,
    pages: pages ?? this.pages,
    keptOriginal: keptOriginal ?? this.keptOriginal,
    error: clearError ? null : (error ?? this.error),
    ffmpegPath: ffmpegPath,
    proxy: proxy,
  );

  JmTasksCompanion toCompanion() => JmTasksCompanion(
    albumId: Value(albumId),
    title: Value(title),
    status: Value(status.name),
    phase: Value(phase),
    error: Value(error),
    pages: Value(pages),
    keptOriginal: Value(keptOriginal),
    ffmpegPath: Value(ffmpegPath),
    proxy: Value(proxy),
    updatedAt: Value(DateTime.now()),
  );

  factory JmTask.fromRow(JmTaskRow r) => JmTask(
    albumId: r.albumId,
    title: r.title,
    status: JmTaskStatus.values.asNameMap()[r.status] ?? JmTaskStatus.failed,
    phase: r.phase,
    pages: r.pages,
    keptOriginal: r.keptOriginal,
    error: r.error,
    ffmpegPath: r.ffmpegPath,
    proxy: r.proxy,
  );

  String get statusLabel => switch (status) {
    JmTaskStatus.downloading => '下载中',
    JmTaskStatus.compressing => '压缩中',
    JmTaskStatus.done => '完成',
    JmTaskStatus.failed => '失败',
  };

  /// 结果一行：下载/压缩明细。
  String? get resultLine => pages == null
      ? null
      : keptOriginal == 0
      ? '$pages 页，全部转为 AVIF'
      : '$pages 页，保留 $keptOriginal 页原图，其余转 AVIF';
}

class _JmTasksNotifier extends Notifier<List<JmTask>> {
  @override
  List<JmTask> build() {
    // 启动即恢复：闪退/被杀前的任务回到列表，进行中的自动续跑
    Future(_restore);
    return const [];
  }

  bool _restored = false;
  DateTime _lastPersistAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    try {
      final db = ref.read(appDatabaseProvider);
      final rows = await (db.select(
        db.jmTasks,
      )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
      final persisted = [for (final r in rows) JmTask.fromRow(r)];
      // 合并策略：内存里已存在的（本次会话刚发起的）以内存为准，不覆盖
      final merged = [...state];
      final resume = <JmTask>[];
      for (final t in persisted) {
        if (merged.any((e) => e.albumId == t.albumId)) continue;
        merged.add(t);
        if (t.status == JmTaskStatus.downloading ||
            t.status == JmTaskStatus.compressing) {
          resume.add(t);
        }
      }
      if (merged.isNotEmpty) state = merged;

      // 清扫上次进程死亡留下的半成品记录（续跑任务的目录还没铺，先排除）
      final root = await resolveLocalRoot(ref.read(settingsRepositoryProvider));
      if (housekeepingPending) {
        markHousekeepingRan();
        // 排除集必须覆盖两路在飞任务：书源下载的占位行此刻目录未建，
        // 漏一个 id 就会被误删（书签/进度一并丢失）
        final inFlightIds = {
          for (final t in merged)
            if (t.status == JmTaskStatus.downloading ||
                t.status == JmTaskStatus.compressing)
              'jm_${t.albumId}',
          for (final t in ref.read(novelTasksProvider))
            if (t.status == NovelTaskStatus.downloading) t.workId,
        };
        final swept = await sweepDanglingLocalWorks(
          db,
          root,
          activeWorkIds: inFlightIds,
        );
        if (swept.removed > 0 || swept.repaired > 0) {
          _log.info(
            'swept dangling local works: ${swept.removed} removed, '
            '${swept.repaired} repaired',
          );
          ref.read(shelfWorksCacheProvider).clear();
          ref
            ..invalidate(shelfWorksProvider)
            ..invalidate(shelfTotalProvider)
            ..invalidate(shelfTagsProvider)
            ..invalidate(shelfStatusesProvider)
            ..invalidate(shelfAuthorsProvider);
        }
        // M7 缓存修剪：图片缓存按上限 LRU、云端小说缓存 512MB、审阅残留整删
        try {
          final tmp = await getTemporaryDirectory();
          final cap =
              int.tryParse(
                await ref
                        .read(settingsRepositoryProvider)
                        .get('cache.imageLimitMb') ??
                    '2048',
              ) ??
              2048;
          await pruneStartupCaches(
            tmpPath: tmp.path,
            localRoot: root,
            imageCapMb: cap,
          );
        } on Object catch (e) {
          _log.warning('cache prune failed: $e');
        }
      }

      // 续跑中断的下载：整条管线幂等（本地目录重铺、行 upsert），重入安全
      final container = rootContainer;
      if (container != null) {
        for (final t in resume) {
          unawaited(
            startJmDownload(
              container,
              albumId: t.albumId,
              ffmpegPath: t.ffmpegPath,
              proxy: t.proxy,
            ),
          );
        }
      }
    } on Object catch (e) {
      _log.warning('jm tasks restore failed: $e');
    }
  }

  Future<void> _persist(JmTask t) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.into(db.jmTasks).insertOnConflictUpdate(t.toCompanion());
    } on Object catch (e) {
      _log.warning('jm task persist failed: $e');
    }
  }

  Future<void> _deleteRow(String albumId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.delete(
        db.jmTasks,
      )..where((t) => t.albumId.equals(albumId))).go();
    } on Object catch (e) {
      _log.warning('jm task delete failed: $e');
    }
  }

  void upsert(JmTask task) {
    final i = state.indexWhere((t) => t.albumId == task.albumId);
    if (i >= 0) {
      state = [...state]..[i] = task;
    } else {
      state = [task, ...state];
    }
    unawaited(_persist(task));
  }

  void patch(String albumId, JmTask Function(JmTask) fn) {
    final i = state.indexWhere((t) => t.albumId == albumId);
    if (i < 0) return;
    state = [...state]..[i] = fn(state[i]);
    final t = state[i];
    // 进度文案高频更新（每页一次）：节流落库；终态（完成/失败）必落——
    // 进程若死在节流窗内，状态停在 downloading，恢复时按续跑处理（幂等）
    final terminal =
        t.status == JmTaskStatus.done || t.status == JmTaskStatus.failed;
    final now = DateTime.now();
    if (terminal ||
        now.difference(_lastPersistAt) >= const Duration(seconds: 2)) {
      _lastPersistAt = now;
      unawaited(_persist(t));
    }
  }

  void remove(String albumId) {
    state = state.where((t) => t.albumId != albumId).toList();
    unawaited(_deleteRow(albumId));
  }
}

final jmTasksProvider = NotifierProvider<_JmTasksNotifier, List<JmTask>>(
  _JmTasksNotifier.new,
);

/// 进行中的任务数（入口角标）；失败/完成的不再计数。
final activeJmTaskCountProvider = Provider<int>(
  (ref) => ref
      .watch(jmTasksProvider)
      .where(
        (t) =>
            t.status == JmTaskStatus.downloading ||
            t.status == JmTaskStatus.compressing,
      )
      .length,
);

/// 启动一次后台下载（下载弹窗、任务列表「重试」与启动续跑共用）。
/// 用 [ProviderContainer] 而非 WidgetRef：弹窗关闭后任务仍在跑。
Future<void> startJmDownload(
  ProviderContainer container, {
  required String albumId,
  required String ffmpegPath,
  required String proxy,
}) async {
  // 同相册已有进行中的任务时跳过：两次下载并发会互删/互写同一本地目录
  final existing = container.read(jmTasksProvider);
  final inFlight = existing.any(
    (t) =>
        t.albumId == albumId &&
        (t.status == JmTaskStatus.downloading ||
            t.status == JmTaskStatus.compressing),
  );
  if (inFlight) return;

  final tasks = container.read(jmTasksProvider.notifier);
  tasks.upsert(
    JmTask(
      albumId: albumId,
      title: '相册 $albumId',
      status: JmTaskStatus.downloading,
      ffmpegPath: ffmpegPath,
      proxy: proxy,
    ),
  );

  void refreshShelf() {
    container.read(shelfWorksCacheProvider).clear();
    container
      ..invalidate(shelfWorksProvider)
      ..invalidate(shelfTotalProvider)
      ..invalidate(shelfTagsProvider)
      ..invalidate(shelfStatusesProvider)
      ..invalidate(shelfAuthorsProvider);
  }

  final pipeline = JmPipeline(
    transcoder: AvifTranscoder(ffmpegPath: ffmpegPath),
    localRoot: await resolveLocalRoot(
      container.read(settingsRepositoryProvider),
    ),
  );

  try {
    final result = await pipeline.download(
      albumId: albumId,
      proxy: proxy,
      onMeta: (meta) async {
        tasks.patch(
          albumId,
          (t) => t.copyWith(title: meta.title, phase: '下载中…'),
        );
        // 只登记新行：此时页数/封面还没就绪，覆盖会把已有行打成半成品
        await pipeline.registerLocal(
          container.read(appDatabaseProvider),
          JmLocalResult(meta: meta, pageCount: 0, localDir: ''),
          insertOnly: true,
        );
        refreshShelf();
      },
      onLocalReady: (r) async {
        tasks.patch(
          albumId,
          (t) => t.copyWith(
            status: JmTaskStatus.compressing,
            phase: '压缩 0/${r.pageCount}',
          ),
        );
        await pipeline.registerLocal(container.read(appDatabaseProvider), r);
        refreshShelf();
      },
      onCompressProgress: (done, total, kept) {
        tasks.patch(
          albumId,
          (t) => t.copyWith(phase: '压缩 $done/$total（保留原图 $kept）'),
        );
      },
      onProgress: (p) => tasks.patch(albumId, (t) => t.copyWith(phase: p)),
    );
    await pipeline.registerLocal(container.read(appDatabaseProvider), result);
    refreshShelf();
    tasks.patch(
      albumId,
      (t) => t.copyWith(
        status: JmTaskStatus.done,
        phase: '',
        pages: result.pageCount,
        keptOriginal: result.keptOriginal,
        clearError: true,
      ),
    );
  } on Object catch (e) {
    tasks.patch(
      albumId,
      (t) => t.copyWith(
        status: JmTaskStatus.failed,
        error: e
            .toString()
            .replaceFirst('StateError: ', '')
            .replaceFirst('Bad state: ', ''),
      ),
    );
  }
}

/// 任务列表面板：查看下载/压缩结果，失败可重试。
class JmTasksSheet extends ConsumerWidget {
  const JmTasksSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const JmTasksSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(jmTasksProvider);
    final uploads = ref.watch(uploadTasksProvider);
    final novels = ref.watch(novelTasksProvider);
    final theme = Theme.of(context);
    final hasAny = tasks.isNotEmpty || uploads.isNotEmpty || novels.isNotEmpty;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (!hasAny)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('暂无任务')),
            )
          else ...[
            if (tasks.isNotEmpty) ...[
              _sectionTitle(theme, 'JM 下载'),
              for (final t in tasks) ...[
                _jmTile(context, ref, t),
                const Divider(height: 1),
              ],
            ],
            if (novels.isNotEmpty) ...[
              _sectionTitle(theme, '小说下载'),
              for (final t in novels) ...[
                novelTaskTile(context, ref, t),
                const Divider(height: 1),
              ],
            ],
            if (uploads.isNotEmpty) ...[
              _sectionTitle(theme, '上传到云端'),
              for (final t in uploads) ...[
                _uploadTile(context, ref, t),
                const Divider(height: 1),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.outline,
        letterSpacing: 2,
      ),
    ),
  );

  Widget _jmTile(BuildContext context, WidgetRef ref, JmTask t) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (t.status) {
        JmTaskStatus.done => Icons.check_circle,
        JmTaskStatus.failed => Icons.error,
        _ => Icons.download,
      }),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        t.error ?? t.resultLine ?? (t.phase.isEmpty ? t.statusLabel : t.phase),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.status == JmTaskStatus.failed)
            TextButton(
              onPressed: () => startJmDownload(
                ProviderScope.containerOf(context, listen: false),
                albumId: t.albumId,
                ffmpegPath: t.ffmpegPath,
                proxy: t.proxy,
              ),
              child: const Text('重试'),
            ),
          if (t.status == JmTaskStatus.done || t.status == JmTaskStatus.failed)
            IconButton(
              tooltip: '移除',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  ref.read(jmTasksProvider.notifier).remove(t.albumId),
            ),
        ],
      ),
    );
  }

  Widget _uploadTile(BuildContext context, WidgetRef ref, UploadTask t) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (t.status) {
        UploadTaskStatus.done => Icons.check_circle,
        UploadTaskStatus.failed => Icons.error,
        _ => Icons.cloud_upload,
      }),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        t.error ?? (t.phase.isEmpty ? t.statusLabel : t.phase),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.status == UploadTaskStatus.failed)
            TextButton(
              onPressed: () async {
                final container = ProviderScope.containerOf(
                  context,
                  listen: false,
                );
                final w = await loadWorkForUpload(container, t.workId);
                if (!context.mounted) return;
                if (w == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('书架里已没有这本，无法重试')),
                  );
                  return;
                }
                await startUploadTasks(container, [w]);
              },
              child: const Text('重试'),
            ),
          if (t.status == UploadTaskStatus.done ||
              t.status == UploadTaskStatus.failed)
            IconButton(
              tooltip: '移除',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  ref.read(uploadTasksProvider.notifier).remove(t.workId),
            ),
        ],
      ),
    );
  }
}

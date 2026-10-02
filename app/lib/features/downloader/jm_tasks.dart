import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/shelf_query.dart';
import '../providers.dart';
import 'avif_transcoder.dart';
import 'jm_pipeline.dart';

enum JmTaskStatus { downloading, compressing, done, failed }

/// 后台下载任务（会话内存态，重启即清）。
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

  /// 启动时的配置快照（重试用）。
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
  List<JmTask> build() => const [];

  void upsert(JmTask task) {
    final i = state.indexWhere((t) => t.albumId == task.albumId);
    if (i >= 0) {
      state = [...state]..[i] = task;
    } else {
      state = [task, ...state];
    }
  }

  void patch(String albumId, JmTask Function(JmTask) fn) {
    final i = state.indexWhere((t) => t.albumId == albumId);
    if (i < 0) return;
    state = [...state]..[i] = fn(state[i]);
  }

  void remove(String albumId) {
    state = state.where((t) => t.albumId != albumId).toList();
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

/// 启动一次后台下载（下载弹窗与任务列表「重试」共用）。
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
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('暂无下载任务')),
            )
          else
            for (final t in tasks) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(switch (t.status) {
                  JmTaskStatus.done => Icons.check_circle,
                  JmTaskStatus.failed => Icons.error,
                  _ => Icons.download,
                }),
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  t.error ??
                      t.resultLine ??
                      (t.phase.isEmpty ? t.statusLabel : t.phase),
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
                    if (t.status == JmTaskStatus.done ||
                        t.status == JmTaskStatus.failed)
                      IconButton(
                        tooltip: '移除',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => ref
                            .read(jmTasksProvider.notifier)
                            .remove(t.albumId),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

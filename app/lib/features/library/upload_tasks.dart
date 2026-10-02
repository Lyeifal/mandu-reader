import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../data/db/app_database.dart';
import '../downloader/jm_pipeline.dart';
import '../providers.dart';
import 'shelf_query.dart';

final _log = Logger('UploadTasks');

enum UploadTaskStatus { queued, uploading, done, failed }

/// 一本作品的上传任务（会话内存态，结果持久化由桶/索引承担）。
class UploadTask {
  const UploadTask({
    required this.workId,
    required this.title,
    required this.status,
    this.phase = '',
    this.error,
  });

  final String workId;
  final String title;
  final UploadTaskStatus status;

  /// 当前阶段文案（排队中/上传 i/N 到桶…）。
  final String phase;
  final String? error;

  UploadTask copyWith({
    String? title,
    UploadTaskStatus? status,
    String? phase,
    String? error,
    bool clearError = false,
  }) => UploadTask(
    workId: workId,
    title: title ?? this.title,
    status: status ?? this.status,
    phase: phase ?? this.phase,
    error: clearError ? null : (error ?? this.error),
  );

  String get statusLabel => switch (status) {
    UploadTaskStatus.queued => '排队中',
    UploadTaskStatus.uploading => '上传中',
    UploadTaskStatus.done => '完成',
    UploadTaskStatus.failed => '失败',
  };
}

class _UploadTasksNotifier extends Notifier<List<UploadTask>> {
  @override
  List<UploadTask> build() => const [];

  void upsert(UploadTask task) {
    final i = state.indexWhere((t) => t.workId == task.workId);
    if (i >= 0) {
      state = [...state]..[i] = task;
    } else {
      state = [...state, task];
    }
  }

  void patch(String workId, UploadTask Function(UploadTask) fn) {
    final i = state.indexWhere((t) => t.workId == workId);
    if (i < 0) return;
    state = [...state]..[i] = fn(state[i]);
  }

  void remove(String workId) {
    state = state.where((t) => t.workId != workId).toList();
  }
}

final uploadTasksProvider =
    NotifierProvider<_UploadTasksNotifier, List<UploadTask>>(
      _UploadTasksNotifier.new,
    );

/// 进行中的任务数（入口角标：排队 + 上传中）。
final activeUploadTaskCountProvider = Provider<int>(
  (ref) => ref
      .watch(uploadTasksProvider)
      .where(
        (t) =>
            t.status == UploadTaskStatus.queued ||
            t.status == UploadTaskStatus.uploading,
      )
      .length,
);

/// 过滤出可入队的作品：同作品已有 排队/进行中/完成 任务时跳过；
/// 失败的可重试（重新入队）。泛型 + id 提取，纯函数可直接单测。
List<T> uploadEligible<T>(
  List<UploadTask> existing,
  List<T> items,
  String Function(T) idOf,
) => items
    .where(
      (it) => !existing.any(
        (t) => t.workId == idOf(it) && t.status != UploadTaskStatus.failed,
      ),
    )
    .toList();

/// 批量上传入口：作品详情页单本与书架多选共用。
/// 队列串行执行（一本传完再传下一本，页面上能看到每本进度），
/// 用 ProviderContainer 而非 WidgetRef：弹层关闭后任务仍在跑。
Future<void> startUploadTasks(
  ProviderContainer container,
  List<Work> works,
) async {
  final client = container.read(bucketClientProvider);
  final eligible = uploadEligible(
    container.read(uploadTasksProvider),
    works,
    (w) => w.id,
  );
  if (eligible.isEmpty) return;
  if (client == null) {
    final tasks = container.read(uploadTasksProvider.notifier);
    for (final w in eligible) {
      tasks.upsert(
        UploadTask(
          workId: w.id,
          title: w.title,
          status: UploadTaskStatus.failed,
          error: '桶客户端不可用：请先在设置中配置并解锁',
        ),
      );
    }
    return;
  }

  final db = container.read(appDatabaseProvider);
  final pipeline = JmPipeline(
    localRoot: await resolveLocalRoot(
      container.read(settingsRepositoryProvider),
    ),
  );
  final tasks = container.read(uploadTasksProvider.notifier);

  void refreshShelf() {
    container.read(shelfWorksCacheProvider).clear();
    container
      ..invalidate(shelfWorksProvider)
      ..invalidate(shelfTotalProvider)
      ..invalidate(shelfTagsProvider)
      ..invalidate(shelfStatusesProvider)
      ..invalidate(shelfAuthorsProvider);
  }

  for (final w in eligible) {
    tasks.upsert(
      UploadTask(
        workId: w.id,
        title: w.title,
        status: UploadTaskStatus.queued,
        phase: '排队中',
      ),
    );
  }
  refreshShelf();

  for (final w in eligible) {
    tasks.patch(
      w.id,
      (t) => t.copyWith(status: UploadTaskStatus.uploading, phase: '准备中…'),
    );
    try {
      if (w.type == 'novel') {
        await pipeline.uploadNovel(
          db: db,
          client: client,
          work: w,
          onProgress: (p) => tasks.patch(w.id, (t) => t.copyWith(phase: p)),
        );
      } else {
        await pipeline.upload(
          db: db,
          client: client,
          work: w,
          onProgress: (p) => tasks.patch(w.id, (t) => t.copyWith(phase: p)),
        );
      }
      tasks.patch(
        w.id,
        (t) => t.copyWith(
          status: UploadTaskStatus.done,
          phase: '',
          clearError: true,
        ),
      );
    } on Object catch (e) {
      _log.warning('upload ${w.id} failed: $e');
      tasks.patch(
        w.id,
        (t) => t.copyWith(
          status: UploadTaskStatus.failed,
          error: e
              .toString()
              .replaceFirst('StateError: ', '')
              .replaceFirst('Bad state: ', ''),
        ),
      );
    }
    // 每本结束都刷新书架：localOnly 标记与索引行已变
    refreshShelf();
  }
}

/// 任务面板「重试」用：按 id 找回作品行。
Future<Work?> loadWorkForUpload(ProviderContainer container, String workId) {
  final db = container.read(appDatabaseProvider);
  return (db.select(
    db.works,
  )..where((t) => t.id.equals(workId))).getSingleOrNull();
}

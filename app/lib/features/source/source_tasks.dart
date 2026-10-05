/// 小说书源下载任务（持久化 + 中断续跑 + 幂等补章，语义对齐 jm_tasks）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../data/db/app_database.dart';
import '../downloader/jm_pipeline.dart';
import '../library/fts_helper.dart';
import '../library/shelf_query.dart';
import '../providers.dart';
import 'source_pipeline.dart';
import 'source_providers.dart';

final _log = Logger('NovelTasks');

enum NovelTaskStatus { downloading, done, failed }

/// 后台小说下载任务。持久化到 drift novel_tasks 表：进程被杀后恢复列表，
/// downloading 态自动续跑（staging tmp 幂等，续跑只补缺失章）。
class NovelTask {
  const NovelTask({
    required this.workId,
    required this.title,
    required this.status,
    required this.snapshot,
    this.phase = '',
    this.error,
    this.failedChapters = const [],
    this.totalChapters,
    this.doneChapters,
  });

  final String workId;
  final String title;
  final NovelTaskStatus status;
  final String phase;
  final String? error;

  /// 缺章清单（1 基章号；failed 时非空，重试续补）。
  final List<int> failedChapters;

  final int? totalChapters;
  final int? doneChapters;

  /// 启动配置快照（恢复续跑/重试的完整输入，JSON 字符串）。
  final String snapshot;

  NovelSnapshot get snapshotObj =>
      NovelSnapshot.fromJson(jsonDecode(snapshot) as Map<String, dynamic>);

  NovelTask copyWith({
    String? title,
    NovelTaskStatus? status,
    String? phase,
    String? error,
    List<int>? failedChapters,
    int? totalChapters,
    int? doneChapters,
    bool clearError = false,
  }) => NovelTask(
    workId: workId,
    title: title ?? this.title,
    status: status ?? this.status,
    phase: phase ?? this.phase,
    error: clearError ? null : (error ?? this.error),
    failedChapters: failedChapters ?? this.failedChapters,
    totalChapters: totalChapters ?? this.totalChapters,
    doneChapters: doneChapters ?? this.doneChapters,
    snapshot: snapshot,
  );

  NovelTasksCompanion toCompanion() => NovelTasksCompanion(
    workId: Value(workId),
    title: Value(title),
    status: Value(status.name),
    phase: Value(phase),
    error: Value(error),
    failedChapters: Value(failedChapters.join(',')),
    totalChapters: Value(totalChapters),
    doneChapters: Value(doneChapters),
    snapshot: Value(snapshot),
    updatedAt: Value(DateTime.now()),
  );

  factory NovelTask.fromRow(NovelTaskRow r) => NovelTask(
    workId: r.workId,
    title: r.title,
    status:
        NovelTaskStatus.values.asNameMap()[r.status] ?? NovelTaskStatus.failed,
    phase: r.phase,
    error: r.error,
    failedChapters: [
      for (final s in r.failedChapters.split(','))
        if (int.tryParse(s) != null) int.parse(s),
    ],
    totalChapters: r.totalChapters,
    doneChapters: r.doneChapters,
    snapshot: r.snapshot,
  );

  String get statusLabel => switch (status) {
    NovelTaskStatus.downloading => '下载中',
    NovelTaskStatus.done => '完成',
    NovelTaskStatus.failed => '失败',
  };

  String? get resultLine => totalChapters == null
      ? null
      : '共 $totalChapters 章${failedChapters.isEmpty ? '' : '，缺 ${failedChapters.length} 章'}';
}

class _NovelTasksNotifier extends Notifier<List<NovelTask>> {
  @override
  List<NovelTask> build() {
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
        db.novelTasks,
      )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
      final persisted = [for (final r in rows) NovelTask.fromRow(r)];
      final merged = [...state];
      final resume = <NovelTask>[];
      for (final t in persisted) {
        if (merged.any((e) => e.workId == t.workId)) continue;
        merged.add(t);
        if (t.status == NovelTaskStatus.downloading) resume.add(t);
      }
      if (merged.isNotEmpty) state = merged;

      // 半成品清扫由 JM 侧统一执行（并集排除 id + 缓存修剪，见 jm_tasks._restore），
      // 本会话去重防止双扫；这里只负责续跑。

      final container = rootContainer;
      if (container != null && resume.isNotEmpty) {
        // 冷启动时 allSourcesProvider 还在异步加载内置规则，此刻直接读
        // 会拿到 null，把续跑任务全部误判「书源不可用」并持久化成 failed——
        // 先等两个源就绪再续跑
        try {
          await ref.read(builtinSourcesProvider.future);
          await ref.read(sourceOverridesProvider.future);
        } on Object catch (e) {
          _log.warning('sources not ready for resume: $e');
        }
        for (final t in resume) {
          unawaited(startNovelDownload(container, task: t));
        }
      }
    } on Object catch (e) {
      _log.warning('novel tasks restore failed: $e');
    }
  }

  Future<void> _persist(NovelTask t) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.into(db.novelTasks).insertOnConflictUpdate(t.toCompanion());
    } on Object catch (e) {
      _log.warning('novel task persist failed: $e');
    }
  }

  Future<void> _deleteRow(String workId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.delete(
        db.novelTasks,
      )..where((t) => t.workId.equals(workId))).go();
    } on Object catch (e) {
      _log.warning('novel task delete failed: $e');
    }
  }

  void upsert(NovelTask task) {
    final i = state.indexWhere((t) => t.workId == task.workId);
    if (i >= 0) {
      state = [...state]..[i] = task;
    } else {
      state = [task, ...state];
    }
    unawaited(_persist(task));
  }

  void patch(String workId, NovelTask Function(NovelTask) fn) {
    final i = state.indexWhere((t) => t.workId == workId);
    if (i < 0) return;
    state = [...state]..[i] = fn(state[i]);
    final t = state[i];
    final terminal =
        t.status == NovelTaskStatus.done || t.status == NovelTaskStatus.failed;
    final now = DateTime.now();
    if (terminal ||
        now.difference(_lastPersistAt) >= const Duration(seconds: 2)) {
      _lastPersistAt = now;
      unawaited(_persist(t));
    }
  }

  void remove(String workId) {
    state = state.where((t) => t.workId != workId).toList();
    unawaited(_deleteRow(workId));
  }
}

final novelTasksProvider =
    NotifierProvider<_NovelTasksNotifier, List<NovelTask>>(
      _NovelTasksNotifier.new,
    );

/// 进行中的小说任务数（入口角标）。
final activeNovelTaskCountProvider = Provider<int>(
  (ref) => ref
      .watch(novelTasksProvider)
      .where((t) => t.status == NovelTaskStatus.downloading)
      .length,
);

/// 启动一次小说下载（详情页「下载到书架」、任务重试、启动续跑共用）。
/// [task] 优先（续跑/重试）；否则从 [snapshot] 新建。
Future<void> startNovelDownload(
  ProviderContainer container, {
  NovelTask? task,
  NovelSnapshot? snapshot,
}) async {
  final snap = task?.snapshotObj ?? snapshot;
  if (snap == null) return;
  final workId = snap.workId;
  final existing = container.read(novelTasksProvider);
  final inFlight = existing.any(
    (t) => t.workId == workId && t.status == NovelTaskStatus.downloading,
  );
  if (inFlight) return;

  final rules = container.read(allSourcesProvider).value ?? const [];
  final rule = findSource(rules, snap.sourceId);
  if (rule == null || rule.disabled) {
    container
        .read(novelTasksProvider.notifier)
        .upsert(
          NovelTask(
            workId: workId,
            title: snap.bookName,
            status: NovelTaskStatus.failed,
            snapshot: jsonEncode(snap.toJson()),
            error: '书源不可用（被禁用或已移除）',
          ),
        );
    return;
  }

  final tasks = container.read(novelTasksProvider.notifier);
  tasks.upsert(
    task?.copyWith(status: NovelTaskStatus.downloading, clearError: true) ??
        NovelTask(
          workId: workId,
          title: snap.bookName,
          status: NovelTaskStatus.downloading,
          snapshot: jsonEncode(snap.toJson()),
          totalChapters: snap.chapters.length,
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

  final root = await resolveLocalRoot(
    container.read(settingsRepositoryProvider),
  );
  final http = await buildSourceHttp(container.read, rule);
  final crawl = await resolveCrawlConfig(container.read, rule);
  final pipeline = SourcePipeline(rule: rule, http: http);

  final db = container.read(appDatabaseProvider);

  // 占位登记：先让书出现在书架（防半成品覆盖用 insertOnly，
  // 字段与 epub 批量导入路径对齐，见 shelf_add_dialog）
  String two(int v) => v.toString().padLeft(2, '0');
  final today =
      '${DateTime.now().year}-${two(DateTime.now().month)}-${two(DateTime.now().day)}';
  await db
      .into(db.works)
      .insert(
        WorksCompanion(
          id: Value(workId),
          type: const Value('novel'),
          title: Value(snap.bookName),
          author: Value(snap.author.isEmpty ? '佚名' : snap.author),
          status: Value(snap.status.contains('完') ? 'completed' : 'ongoing'),
          tags: const Value('[]'),
          hasZh: const Value(true),
          zhQuality: const Value('medium'),
          publishedAt: Value(today.substring(0, 7)),
          lastUpdated: Value(today),
          cover: const Value(''),
          localOnly: const Value(true),
          origin: Value('source:${snap.sourceId}'),
          syncedAt: Value(DateTime.now()),
        ),
        onConflict: DoNothing(),
      );
  // 关键词搜索（works_fts）同步维护：书源下载占位登记不漏写
  await upsertWorkFts(
    db,
    id: workId,
    title: snap.bookName,
    author: snap.author.isEmpty ? '佚名' : snap.author,
  );
  refreshShelf();

  try {
    await pipeline.download(
      root: root,
      snap: snap,
      concurrency: crawl.concurrency,
      attempts: crawl.attempts,
      onProgress: (p) => tasks.patch(workId, (t) => t.copyWith(phase: p)),
      onCount: (done, total) => tasks.patch(
        workId,
        (t) => t.copyWith(doneChapters: done, totalChapters: total),
      ),
    );

    // 终登记：补齐字数/封面/时间
    final txtFile = File('$root/$workId/book.txt');
    final totalChars = txtFile.existsSync()
        ? txtFile.readAsStringSync().length
        : 0;
    final hasCover = File('$root/$workId/cover.jpg').existsSync();
    await (db.update(db.works)..where((t) => t.id.equals(workId))).write(
      WorksCompanion(
        totalChars: Value(totalChars),
        lastUpdated: Value(today),
        cover: Value(hasCover ? 'cover.jpg' : ''),
        syncedAt: Value(DateTime.now()),
      ),
    );
    refreshShelf();
    tasks.patch(
      workId,
      (t) => t.copyWith(
        status: NovelTaskStatus.done,
        phase: '',
        doneChapters: t.totalChapters,
        failedChapters: const [],
        clearError: true,
      ),
    );
  } on NovelDownloadIncomplete catch (e) {
    tasks.patch(
      workId,
      (t) => t.copyWith(
        status: NovelTaskStatus.failed,
        error: '缺 ${e.failedChapters.length} 章（重试续补）',
        failedChapters: e.failedChapters,
      ),
    );
  } on Object catch (e) {
    tasks.patch(
      workId,
      (t) => t.copyWith(
        status: NovelTaskStatus.failed,
        error: e
            .toString()
            .replaceFirst('StateError: ', '')
            .replaceFirst('Bad state: ', ''),
      ),
    );
  }
}

/// 任务面板的小说任务 tile（JmTasksSheet 第三段引用）。
Widget novelTaskTile(BuildContext context, WidgetRef ref, NovelTask t) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(switch (t.status) {
      NovelTaskStatus.done => Icons.check_circle,
      NovelTaskStatus.failed => Icons.error,
      _ => Icons.menu_book_outlined,
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
        if (t.status == NovelTaskStatus.failed)
          TextButton(
            onPressed: () => startNovelDownload(
              ProviderScope.containerOf(context, listen: false),
              task: t,
            ),
            child: const Text('重试'),
          ),
        if (t.status == NovelTaskStatus.done ||
            t.status == NovelTaskStatus.failed)
          IconButton(
            tooltip: '移除',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () =>
                ref.read(novelTasksProvider.notifier).remove(t.workId),
          ),
      ],
    ),
  );
}

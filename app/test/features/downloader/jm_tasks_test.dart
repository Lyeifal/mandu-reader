import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/downloader/jm_models.dart';
import 'package:mandu_reader/features/downloader/jm_pipeline.dart';
import 'package:mandu_reader/features/downloader/jm_tasks.dart';
import 'package:mandu_reader/features/library/local_sweep.dart';
import 'package:mandu_reader/features/providers.dart';
import 'package:mandu_reader/features/settings/settings_repository.dart';

class _BlockingPipeline extends JmPipeline {
  final gate = Completer<void>();
  final started = <String>[];
  var active = 0;
  var peak = 0;

  @override
  Future<JmLocalResult> download({
    required String albumId,
    String proxy = '',
    FutureOr<void> Function(JmAlbumMeta)? onMeta,
    FutureOr<void> Function(JmLocalResult)? onLocalReady,
    void Function(int, int, int)? onCompressProgress,
    required void Function(String) onProgress,
  }) async {
    started.add(albumId);
    active++;
    if (active > peak) peak = active;
    try {
      await gate.future;
      if (albumId == '0') throw StateError('test failure');
      return JmLocalResult(
        meta: JmAlbumMeta(
          albumId: albumId,
          title: albumId,
          authors: const [],
          tags: const [],
          works: const [],
          pubDate: '2026-10-18',
          updateDate: '2026-10-18',
          pageCount: 1,
        ),
        pageCount: 1,
        localDir: '',
      );
    } finally {
      active--;
    }
  }

  @override
  Future<void> registerLocal(
    AppDatabase db,
    JmLocalResult result, {
    bool insertOnly = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('恢复 39 个任务时仅执行两本，排队可持久化且失败会释放名额', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dir = await Directory.systemTemp.createTemp('jm_tasks_test_');
    await SettingsRepository(db).set('storage.local_dir', dir.path);
    for (var i = 0; i < 39; i++) {
      await db
          .into(db.jmTasks)
          .insert(
            JmTask(
              albumId: '$i',
              title: 'title $i',
              status: [
                JmTaskStatus.queued,
                JmTaskStatus.downloading,
                JmTaskStatus.compressing,
              ][i % 3],
              ffmpegPath: '',
              proxy: '',
            ).toCompanion(),
          );
    }
    markHousekeepingRan();
    final pipeline = _BlockingPipeline();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        jmPipelineFactoryProvider.overrideWithValue((_, _) => pipeline),
      ],
    );
    final previous = rootContainer;
    rootContainer = container;
    final queued = Completer<void>();
    final finished = Completer<void>();
    final sub = container.listen(jmTasksProvider, (_, tasks) {
      if (tasks.where((t) => t.status == JmTaskStatus.queued).length == 37 &&
          tasks.where((t) => t.status == JmTaskStatus.downloading).length ==
              2 &&
          !queued.isCompleted) {
        queued.complete();
      }
      if (tasks.length == 39 &&
          tasks.every((t) => !t.isPending) &&
          !finished.isCompleted) {
        finished.complete();
      }
    }, fireImmediately: true);
    try {
      await queued.future.timeout(const Duration(seconds: 10));
      // 读取队列态之后，管线创建还需一次数据库异步读取。
      for (var i = 0; i < 100 && pipeline.started.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(pipeline.started.length, 2);
      expect(container.read(activeJmTaskCountProvider), 39);
      expect(
        container
            .read(jmTasksProvider)
            .every((t) => t.title == 'title ${t.albumId}'),
        isTrue,
      );
      await startJmDownload(
        container,
        albumId: pipeline.started.first,
        ffmpegPath: '',
        proxy: '',
        resume: true,
      );
      expect(pipeline.started.length, 2);
      final persisted = await db.select(db.jmTasks).get();
      expect(persisted.where((r) => r.status == 'queued').length, 37);
      pipeline.gate.complete();
      await finished.future.timeout(const Duration(seconds: 10));
      expect(pipeline.peak, 2);
      expect(pipeline.started.toSet().length, 39);
      expect(container.read(activeJmTaskCountProvider), 0);
      expect(
        container
            .read(jmTasksProvider)
            .where((t) => t.status == JmTaskStatus.done)
            .length,
        38,
      );
      expect(
        container
            .read(jmTasksProvider)
            .singleWhere((t) => t.albumId == '0')
            .status,
        JmTaskStatus.failed,
      );
      // 等待异步终态落库队列清空，避免销毁容器时仍有写操作。
      await db.select(db.jmTasks).get();
    } finally {
      if (!pipeline.gate.isCompleted) pipeline.gate.complete();
      sub.close();
      rootContainer = previous;
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  group('JmTask 持久化映射', () {
    test('toCompanion → fromRow 往返一致', () {
      const task = JmTask(
        albumId: '123456',
        title: '测试相册',
        status: JmTaskStatus.compressing,
        ffmpegPath: r'D:\tools\ffmpeg.exe',
        proxy: 'http://127.0.0.1:7897',
        phase: '压缩 3/42',
        pages: 42,
        keptOriginal: 1,
      );
      final c = task.toCompanion();
      final restored = JmTask.fromRow(
        JmTaskRow(
          albumId: c.albumId.value,
          title: c.title.value,
          status: c.status.value,
          phase: c.phase.value,
          error: c.error.value,
          pages: c.pages.value,
          keptOriginal: c.keptOriginal.value,
          ffmpegPath: c.ffmpegPath.value,
          proxy: c.proxy.value,
          updatedAt: c.updatedAt.value,
        ),
      );
      expect(restored.albumId, task.albumId);
      expect(restored.title, task.title);
      expect(restored.status, task.status);
      expect(restored.phase, task.phase);
      expect(restored.pages, task.pages);
      expect(restored.keptOriginal, task.keptOriginal);
      expect(restored.ffmpegPath, task.ffmpegPath);
      expect(restored.proxy, task.proxy);
    });

    test('未知状态回退 failed（旧版本写入的兼容）', () {
      final t = JmTask.fromRow(
        JmTaskRow(
          albumId: '1',
          title: 'x',
          status: 'weird',
          phase: '',
          error: null,
          pages: null,
          keptOriginal: null,
          ffmpegPath: '',
          proxy: '',
          updatedAt: DateTime(2026),
        ),
      );
      expect(t.status, JmTaskStatus.failed);
    });
  });
}

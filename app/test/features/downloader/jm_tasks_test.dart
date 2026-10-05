import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/downloader/jm_tasks.dart';

void main() {
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

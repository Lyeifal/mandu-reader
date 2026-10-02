import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/library/upload_tasks.dart';

void main() {
  group('uploadEligible', () {
    UploadTask task(String id, UploadTaskStatus s) =>
        UploadTask(workId: id, title: id, status: s);

    test('排队/进行中/完成 的作品跳过；失败的保留可重试', () {
      final existing = [
        task('a', UploadTaskStatus.queued),
        task('b', UploadTaskStatus.uploading),
        task('c', UploadTaskStatus.done),
        task('d', UploadTaskStatus.failed),
      ];
      final out = uploadEligible(existing, [
        'a',
        'b',
        'c',
        'd',
        'e',
      ], (id) => id);
      expect(out, ['d', 'e']);
    });

    test('空任务列表：全部可入队', () {
      expect(uploadEligible(const [], ['x', 'y'], (id) => id), ['x', 'y']);
    });
  });
}

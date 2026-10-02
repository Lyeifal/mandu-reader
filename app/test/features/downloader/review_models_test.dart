import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/downloader/review_models.dart';

void main() {
  group('pendingPageKeys', () {
    test('只留非 AVIF 的数字页：封面/章节表/已压页剔除', () {
      final keys = [
        'library/漫画/A/本/v001/001.jpg',
        'library/漫画/A/本/v001/002.avif', // 已压
        'library/漫画/A/本/v001/003.webp',
        'library/漫画/A/本/v001/cover.jpg',
        'library/漫画/A/本/v001/chapters.json',
        'library/漫画/A/本/v001/004.png',
      ];
      expect(pendingPageKeys(keys), [
        'library/漫画/A/本/v001/001.jpg',
        'library/漫画/A/本/v001/003.webp',
        'library/漫画/A/本/v001/004.png',
      ]);
    });

    test('全部已压时为空', () {
      final keys = [
        'library/漫画/A/本/v001/001.avif',
        'library/漫画/A/本/v001/002.avif',
      ];
      expect(pendingPageKeys(keys), isEmpty);
    });
  });

  group('ReviewItem', () {
    const item = ReviewItem(
      target: ReviewTarget(key: 'k', isFirstPage: true),
      originalPath: 'a',
      avifPath: 'b',
      originalBytes: 1000,
      avifBytes: 400,
    );

    test('节省比例', () {
      expect(item.saving, closeTo(0.6, 1e-9));
    });

    test('原图为 0 字节时节省按 0（不除零）', () {
      const zero = ReviewItem(
        target: ReviewTarget(key: 'k', isFirstPage: false),
        originalPath: 'a',
        avifPath: 'b',
        originalBytes: 0,
        avifBytes: 0,
      );
      expect(zero.saving, 0);
    });
  });

  group('formatSize', () {
    test('KB / MB 分档', () {
      expect(formatSize(512), '1 KB');
      expect(formatSize(245 * 1024), '245 KB');
      expect(formatSize(1536 * 1024), '1.5 MB');
    });
  });

  group('clampSplit', () {
    test('钳到 2%..98%', () {
      expect(clampSplit(0), 0.02);
      expect(clampSplit(1), 0.98);
      expect(clampSplit(0.5), 0.5);
    });
  });
}

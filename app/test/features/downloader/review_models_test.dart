import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/bucket/bucket_client.dart';
import 'package:mandu_reader/features/downloader/review_models.dart';

void main() {
  group('summarizePages（选书统计）', () {
    test('统计总页/原图页/原图体积，封面与已压页不算', () {
      final s = summarizePages(const [
        BucketObjectInfo(key: 'library/漫画/A/本/v001/001.jpg', size: 1000),
        BucketObjectInfo(key: 'library/漫画/A/本/v001/002.avif', size: 400),
        BucketObjectInfo(key: 'library/漫画/A/本/v001/003.webp', size: 2500),
        BucketObjectInfo(key: 'library/漫画/A/本/v001/cover.jpg', size: 9000),
        BucketObjectInfo(key: 'library/漫画/A/本/v001/chapters.json', size: 10),
      ]);
      expect(s.total, 3);
      expect(s.raw, 2);
      expect(s.avif, 1);
      expect(s.rawBytes, 3500); // 1000 + 2500
      expect(s.hasPending, isTrue);
    });

    test('全部已压：hasPending 为 false（选书列表不显示）', () {
      final s = summarizePages(const [
        BucketObjectInfo(key: 'library/漫画/A/本/v001/001.avif', size: 400),
        BucketObjectInfo(key: 'library/漫画/A/本/v001/002.avif', size: 400),
      ]);
      expect(s.raw, 0);
      expect(s.hasPending, isFalse);
    });
  });

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

import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/bucket/path_helper.dart';

void main() {
  test('常量路径', () {
    expect(LibraryPaths.worksIndex, 'library/_index/works.jsonl');
    expect(LibraryPaths.eventsLog, 'library/_state/events.jsonl');
  });

  group('sanitizeSegment', () {
    test('去除非法字符与控制字符', () {
      expect(
        LibraryPaths.sanitizeSegment('a/b\\c:d*e?f"g<h>i|j'),
        'abcdefghij',
      );
      expect(LibraryPaths.sanitizeSegment('  正常 名字  '), '正常 名字');
    });

    test('空与全非法回退 unnamed', () {
      expect(LibraryPaths.sanitizeSegment(''), 'unnamed');
      expect(LibraryPaths.sanitizeSegment('///'), 'unnamed');
    });

    test('长度截断到 80', () {
      expect(LibraryPaths.sanitizeSegment('字' * 100).length, 80);
    });

    test('截断不切开 UTF-16 代理对（emoji）', () {
      // 79 个 ASCII + emoji（2 个 code unit）= 81 unit，截到 80 会切在高代理位
      expect(LibraryPaths.sanitizeSegment('a' * 79 + '😀'), 'a' * 79);
    });
  });

  group('normalizeKey', () {
    test('无 library/ 前缀的索引 cover 补全前缀', () {
      expect(
        LibraryPaths.normalizeKey('小说/佚名/书名/cover.avif'),
        'library/小说/佚名/书名/cover.avif',
      );
    });

    test('已带前缀的保持不变', () {
      expect(
        LibraryPaths.normalizeKey('library/小说/佚名/书名/cover.avif'),
        'library/小说/佚名/书名/cover.avif',
      );
    });
  });

  group('novel 路径', () {
    test('带系列', () {
      expect(
        LibraryPaths.novelTxt(author: '佚名', series: '散落短篇', title: '书名'),
        'library/小说/佚名/散落短篇/书名/book.txt',
      );
    });

    test('无系列时跳过系列段', () {
      expect(
        LibraryPaths.novelDir(author: '佚名', title: '书名'),
        'library/小说/佚名/书名',
      );
    });

    test('作者名含非法字符被清洗', () {
      expect(
        LibraryPaths.novelMeta(author: 'a/b', title: 't'),
        'library/小说/ab/t/meta.json',
      );
    });
  });

  group('manga 路径', () {
    test('卷号三位补零', () {
      expect(
        LibraryPaths.mangaDir(
          author: '山田太郎',
          series: '奇幻系列',
          title: '本',
          volume: 1,
        ),
        'library/漫画/山田太郎/奇幻系列/本/v001',
      );
      expect(
        LibraryPaths.mangaPage(
          LibraryPaths.mangaDir(author: 'A', title: '本', volume: 12),
          7,
        ),
        'library/漫画/A/本/v012/007.avif',
      );
    });
  });

  test('fontFile 前缀与清洗', () {
    expect(
      LibraryPaths.fontFile('LXGW-Bold.ttf'),
      'library/_fonts/LXGW-Bold.ttf',
    );
  });
}

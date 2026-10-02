import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/downloader/avif_transcoder.dart';
import 'package:mandu_reader/features/downloader/cloud_compress.dart';
import 'package:mandu_reader/features/downloader/jm_models.dart';
import 'package:mandu_reader/features/library/shelf_query.dart';

void main() {
  group('parseJmDriverLine', () {
    const metaJson =
        '{"album_id":"123456","title":"某本子","authors":["作者甲"],'
        '"tags":["奇幻","汉化"],"works":["某系列"],"pub_date":"2024-03-15",'
        '"update_date":"2024-03-20","page_count":42}';

    test('META 行', () {
      final line = parseJmDriverLine('META $metaJson');
      expect(line, isA<JmMetaLine>());
      final meta = (line! as JmMetaLine).meta;
      expect(meta.albumId, '123456');
      expect(meta.title, '某本子');
      expect(meta.author, '作者甲');
      expect(meta.series, '某系列');
      expect(meta.tags, ['奇幻', '汉化']);
      expect(meta.pageCount, 42);
    });

    test('FILES / DONE / ERROR 行', () {
      final files = parseJmDriverLine('FILES ["a.jpg","b.png"]');
      expect((files! as JmFilesLine).files, ['a.jpg', 'b.png']);
      expect(parseJmDriverLine('DONE'), isA<JmDoneLine>());
      final err = parseJmDriverLine('ERROR something broke');
      expect((err! as JmErrorLine).message, 'something broke');
    });

    test('非协议行返回 null', () {
      expect(parseJmDriverLine('jmcomic 普通日志'), isNull);
      expect(parseJmDriverLine(''), isNull);
    });
  });

  group('parseJmAlbumId', () {
    test('纯数字与 URL', () {
      expect(parseJmAlbumId('123456'), '123456');
      expect(parseJmAlbumId('https://18comic.org/album/123456/'), '123456');
      expect(parseJmAlbumId('album-98765-extra'), '98765');
      expect(parseJmAlbumId('abc'), isNull);
    });
  });

  group('jmMonth', () {
    test('归一化到月', () {
      expect(jmMonth('2024-03-15'), '2024-03');
      expect(jmMonth('2024/03'), '2024-03');
      expect(jmMonth('bad'), isNull);
      expect(jmMonth('2024-13'), isNull);
    });
  });

  group('orderTagsByRecency 标签 MRU 排序', () {
    test('最近点过的在前，其余按计数降序', () {
      const tags = [
        (tag: '奇幻', count: 10),
        (tag: '慢热', count: 5),
        (tag: '校园', count: 8),
        (tag: '短篇', count: 1),
      ];
      final ordered = orderTagsByRecency(tags, const ['短篇', '奇幻']);
      expect(ordered.map((t) => t.tag).toList(), ['短篇', '奇幻', '校园', '慢热']);
    });

    test('recent 里有但当前不存在的标签被忽略', () {
      const tags = [(tag: '奇幻', count: 3)];
      expect(orderTagsByRecency(tags, const ['不存在', '奇幻']).single.tag, '奇幻');
    });
  });

  group('worthReplacing 压缩判定', () {
    test('压完更大 → 不替换', () {
      expect(worthReplacing(1000, 1200, 0.99), isFalse);
      expect(worthReplacing(1000, 1000, 0.99), isFalse);
    });

    test('画质可接受 → 只要变小就替换', () {
      expect(worthReplacing(1000, 900, 0.98), isTrue);
      expect(worthReplacing(1000, 600, 0.99), isTrue);
    });

    test('画质损失但省得少 → 不替换；省得多 → 替换', () {
      expect(worthReplacing(1000, 800, 0.90), isFalse); // 省 20% < 30%
      expect(worthReplacing(1000, 500, 0.90), isTrue); // 省 50%
    });

    test('ssim 拿不到 → 要求更狠的节省（40%）', () {
      expect(worthReplacing(1000, 700, null), isFalse); // 省 30% 不够
      expect(worthReplacing(1000, 500, null), isTrue);
    });

    test('体积悬殊（省 ≥50%）→ 不再看 ssim 直接替换', () {
      expect(worthReplacing(300000, 40000, 0.90), isTrue); // webp→avif 小一个量级
      expect(worthReplacing(300000, 40000, null), isTrue);
      expect(worthReplacing(1000, 800, 0.90), isFalse); // 省 20% 仍走画质判定
    });
  });

  group('AvifTranscoder 最小体积极档', () {
    test('libaom crf45 参数（体积优先）', () {
      final args = AvifTranscoder().buildArgs('in.png', 'out.avif');
      String val(String flag) => args[args.indexOf(flag) + 1];
      expect(val('-c:v'), 'libaom-av1');
      expect(val('-crf'), '45');
      expect(val('-pix_fmt'), 'yuv420p');
      expect(val('-cpu-used'), '0');
      expect(val('-aom-params'), contains('tune=ssim'));
      expect(args, contains('-still-picture'));
      expect(val('-vf'), contains('crop='));
      expect(args.last, 'out.avif');
    });
  });

  group('pageKeysOf（云端压缩选页）', () {
    test('只挑三位数字页并排序，封面/章节表剔除', () {
      final keys = [
        'library/漫画/作者/系列/书名/v001/cover.webp',
        'library/漫画/作者/系列/书名/v001/010.webp',
        'library/漫画/作者/系列/书名/v001/002.jpg',
        'library/漫画/作者/系列/书名/v001/meta.json',
        'library/漫画/作者/系列/书名/v001/001.avif',
        'library/漫画/作者/系列/书名/v001/1000.webp', // 四位数：不是页码命名
      ];
      final pages = pageKeysOf(keys);
      expect(pages, [
        'library/漫画/作者/系列/书名/v001/001.avif',
        'library/漫画/作者/系列/书名/v001/002.jpg',
        'library/漫画/作者/系列/书名/v001/010.webp',
      ]);
    });
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/jm/jm_api.dart';
import 'package:mandu_reader/features/jm/jm_downloader.dart';
import 'package:mandu_reader/features/jm/jm_models.dart';

class _FakeJmApi extends JmApiClient {
  _FakeJmApi({this.failOnce = false});

  bool failOnce;
  final requests = <String>[];

  @override
  Future<void> bootstrap() async {}

  @override
  void close() {}

  @override
  Future<JmAlbumInfo> getAlbum(String albumId) async => const JmAlbumInfo(
    id: '100',
    title: '多章节',
    authors: [],
    tags: [],
    works: [],
    episodes: [
      JmEpisode(id: '101', name: '第一章', sort: '1'),
      JmEpisode(id: '102', name: '第二章', sort: '2'),
    ],
    pageCount: 4,
    pubDate: '2026-10-01',
  );

  @override
  Future<JmPhotoInfo> getPhoto(String photoId) async => JmPhotoInfo(
    id: photoId,
    name: photoId,
    images: const ['001.gif', '002.gif'],
  );

  @override
  Future<int> getScrambleId(String photoId) async => 0;

  @override
  String imageUrl(String photoId, String filename) => '$photoId/$filename';

  @override
  Future<Uint8List> downloadImage(String url) async {
    requests.add(url);
    if (failOnce && url == '101/002.gif') {
      failOnce = false;
      throw StateError('临时断网');
    }
    return Uint8List.fromList(url.codeUnits);
  }
}

class _NetworkActivity {
  var active = 0;
  var peak = 0;
}

class _ConcurrentJmApi extends _FakeJmApi {
  _ConcurrentJmApi(this.activity);

  final _NetworkActivity activity;

  @override
  Future<JmPhotoInfo> getPhoto(String photoId) async => JmPhotoInfo(
    id: photoId,
    name: photoId,
    images: [for (var i = 1; i <= 12; i++) '$i.gif'],
  );

  @override
  Future<Uint8List> downloadImage(String url) async {
    activity.active++;
    if (activity.active > activity.peak) activity.peak = activity.active;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return await super.downloadImage(url);
    } finally {
      activity.active--;
    }
  }
}

void main() {
  test('多本多章同时下载仍共享最多 8 个图片处理名额', () async {
    final dir = await Directory.systemTemp.createTemp('jm_concurrency_test_');
    addTearDown(() => dir.delete(recursive: true));
    final activity = _NetworkActivity();
    final results = await Future.wait([
      for (var i = 0; i < 3; i++)
        JmDartDownloader(client: _ConcurrentJmApi(activity))
            .download('100', '${dir.path}/$i', onProgress: (_) {}),
    ]);
    expect(results.map((r) => r.files.length), [24, 24, 24]);
    expect(activity.peak, inInclusiveRange(2, 8));
    expect(activity.active, 0);
  });

  test('多章节相同页码不覆盖，按章节和章内顺序返回', () async {
    final dir = await Directory.systemTemp.createTemp('jm_downloader_test_');
    addTearDown(() => dir.delete(recursive: true));
    final result = await JmDartDownloader(client: _FakeJmApi())
        .download('100', dir.path, onProgress: (_) {});

    expect(result.files.length, 4);
    expect(result.files.toSet().length, 4);
    expect(
      [for (final path in result.files) await File(path).readAsString()],
      ['101/001.gif', '101/002.gif', '102/001.gif', '102/002.gif'],
    );
  });

  test('单页失败后重试复用已写页面', () async {
    final dir = await Directory.systemTemp.createTemp('jm_resume_test_');
    addTearDown(() => dir.delete(recursive: true));
    final first = _FakeJmApi(failOnce: true);
    await expectLater(
      JmDartDownloader(client: first)
          .download('100', dir.path, onProgress: (_) {}),
      throwsA(predicate((e) => e.toString().contains('章节 101 第 2 页'))),
    );
    final second = _FakeJmApi();
    final result = await JmDartDownloader(client: second)
        .download('100', dir.path, onProgress: (_) {});
    expect(result.files.length, 4);
    expect(second.requests, ['101/002.gif']);
  });
}

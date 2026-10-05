import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../downloader/jm_models.dart' show JmAlbumMeta;
import 'jm_api.dart';
import 'jm_scramble.dart';

/// 下载结果：元数据 + 图片文件绝对路径（有序）。
class JmDartResult {
  const JmDartResult({required this.meta, required this.files});

  final JmAlbumMeta meta;
  final List<String> files;
}

/// 纯 Dart 的 JM 下载编排（替代 Python 驱动）：
/// 详情 → 逐 photo 并发拉图（章级信号量、图级并发）→ 还原 scramble → 写盘。
///
/// 进度回调语义与旧驱动一致（任务列表直接用）。
class JmDartDownloader {
  JmDartDownloader({String proxy = ''}) : _client = JmApiClient(proxy: proxy);

  final JmApiClient _client;

  static const _photoConcurrency = 4;

  /// 图级并发：解码+条带还原+JPEG 重编码在独立 isolate 执行（见
  /// [_decodeInIsolate]），不阻塞 UI；并发仍收敛在个位数，避免把
  /// CPU 占满影响浏览，也对 CDN 友好。
  static const _imageConcurrency = 8;

  /// 下载整本到 [outDir]（调用方准备好的工作目录）。
  Future<JmDartResult> download(
    String albumId,
    String outDir, {
    required void Function(String phase) onProgress,
    void Function(int done, int total, int kept)? onPageDone,
  }) async {
    // 无论成功失败都释放 HTTP 连接
    try {
      return await _downloadInner(
        albumId,
        outDir,
        onProgress: onProgress,
        onPageDone: onPageDone,
      );
    } finally {
      _client.close();
    }
  }

  Future<JmDartResult> _downloadInner(
    String albumId,
    String outDir, {
    required void Function(String phase) onProgress,
    void Function(int done, int total, int kept)? onPageDone,
  }) async {
    await _client.bootstrap();

    onProgress('获取相册信息…');
    final album = await _client.getAlbum(albumId);
    final meta = JmAlbumMeta(
      albumId: album.id,
      title: album.title,
      authors: album.authors,
      tags: album.tags,
      works: album.works,
      pubDate: album.pubDate,
      updateDate: album.pubDate,
      pageCount: album.pageCount,
    );
    onProgress('《${album.title}》 共 ${album.photoIds.length} 章，开始下载…');

    final dir = Directory(outDir);
    await dir.create(recursive: true);

    // 章级并发
    final photoIds = album.photoIds;
    final photoResults = await _mapLimited(
      photoIds,
      _photoConcurrency,
      (photoId) => _downloadPhoto(photoId, dir.path, onProgress),
    );

    final files = photoResults.expand((e) => e).toList()
      ..sort((a, b) => _seqOf(a).compareTo(_seqOf(b)));

    onProgress('下载完成 ${files.length} 页');
    return JmDartResult(meta: meta, files: files);
  }

  int _seqOf(String path) {
    final m = RegExp(r'(\d{3,5})\.\w+$').firstMatch(p.basename(path));
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  Future<List<String>> _downloadPhoto(
    String photoId,
    String outDir,
    void Function(String) onProgress,
  ) async {
    final photo = await _client.getPhoto(photoId);
    if (photo.images.isEmpty) {
      throw StateError('章节 $photoId 没有图片');
    }
    final scrambleId = await _client.getScrambleId(photoId);

    final paths = List<String?>.filled(photo.images.length, null);
    var downloaded = 0;
    final indexes = [for (var i = 0; i < photo.images.length; i++) i];
    await _mapLimited(indexes, _imageConcurrency, (i) async {
      final name = photo.images[i];
      final url = _client.imageUrl(photoId, name);
      final bytes = await _client.downloadImage(url);
      // 还原后重编码为 JPEG，扩展名用 .jpg；gif/老图原样保留原扩展名
      final doDecode = _needDecode(name);
      final ext = doDecode ? 'jpg' : extOf(name);
      final out = p.join(
        outDir,
        photo.images.length > 999
            ? '${(i + 1).toString().padLeft(5, '0')}.$ext'
            : '${(i + 1).toString().padLeft(3, '0')}.$ext',
      );
      final data = doDecode
          ? await _decodeInIsolate(
              bytes,
              jmScrambleNum(scrambleId, int.parse(photoId), baseOf(name)),
            )
          : bytes;
      await File(out).writeAsBytes(data);
      paths[i] = out;
      downloaded++;
      onProgress('下载 $photoId 第 $downloaded/${photo.images.length} 页');
    });
    return [for (final p in paths) ?p];
  }

  static String extOf(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? 'webp' : filename.substring(dot + 1);
  }

  static String baseOf(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? filename : filename.substring(0, dot);
  }

  static bool _needDecode(String filename) =>
      !filename.toLowerCase().endsWith('.gif');

  /// 解码 + 条带还原 + 重编码整体进独立 isolate：image 包是纯 Dart 实现，
  /// 在主 isolate 跑会让浏览/翻页全程掉帧（2026-10-03 实测卡顿根源）。
  Future<Uint8List> _decodeInIsolate(Uint8List bytes, int num) =>
      Isolate.run(() => jmDecodeImage(bytes, num));

  /// 限制并发的 map：保持输入顺序返回结果；单个失败即整体失败。
  Future<List<T>> _mapLimited<T, R>(
    List<R> items,
    int limit,
    Future<T> Function(R item) fn,
  ) async {
    final results = List<T?>.filled(items.length, null);
    var index = 0;
    final slots = List.generate(
      limit.clamp(1, items.isEmpty ? 1 : items.length),
      (_) async {
        while (true) {
          final i = index;
          if (i >= items.length) return;
          index++;
          results[i] = await fn(items[i]);
        }
      },
    );
    await Future.wait(slots);
    return [for (final r in results) r as T];
  }
}

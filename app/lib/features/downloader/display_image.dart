import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 进程级共享 HttpClient：每张图新建连接的开销不小，应用生命周期内复用。
/// 代理场景在 cacheImageFile 内另起独立 client（findProxy 是 client 级的）。
final _sharedClient = HttpClient();

/// 下载 URL 到临时缓存（按 URL 的 path 哈希，幂等），返回本地路径。
/// key 只取 path：预签名 URL 的 query（X-Amz-Signature 等）每次不同，
/// 参与 key 会让缓存永远不命中。[proxy] 仅供需要代理的源（JM CDN）使用。
/// 公开供横图尺寸探测等非显示路径复用：与显示层共享同一份缓存，
/// 探测不会导致二次下载。
Future<String> cacheImageFile(String url, {String? proxy}) async {
  final key = md5.convert(utf8.encode(url.split('?').first)).toString();
  final tmp = await getTemporaryDirectory();
  final dir = Directory(p.join(tmp.path, 'mandu_img_cache'));
  await dir.create(recursive: true);
  final ext = p.extension(url.split('?').first);
  final file = File(p.join(dir.path, '$key${ext.isEmpty ? '.bin' : ext}'));
  if (await file.exists()) return file.path;

  final client = _sharedClient;
  final clean = proxy?.trim() ?? '';
  if (clean.isNotEmpty) {
    // 代理场景仍用独立 client（共享 client 的 findProxy 是全局的）
    final proxied = HttpClient()
      ..findProxy = (uri) =>
          'PROXY ${clean.replaceFirst(RegExp('^https?://'), '')}';
    try {
      return await _downloadTo(proxied, url, file);
    } finally {
      proxied.close();
    }
  }
  return _downloadTo(client, url, file);
}

Future<String> _downloadTo(HttpClient client, String url, File file) async {
  final req = await client.getUrl(Uri.parse(url));
  final resp = await req.close().timeout(const Duration(seconds: 60));
  if (resp.statusCode != 200) {
    throw StateError('下载失败(${resp.statusCode})：${url.split('?').first}');
  }
  final builder = BytesBuilder();
  await for (final chunk in resp) {
    builder.add(chunk);
  }
  await file.writeAsBytes(builder.toBytes());
  return file.path;
}

Widget _fileImage(String path, BoxFit fit, Widget fallback, int? cacheWidth) {
  if (p.extension(path).toLowerCase() == '.avif') {
    return AvifImage.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => fallback,
    );
  }
  return Image.file(
    File(path),
    fit: fit,
    cacheWidth: cacheWidth,
    errorBuilder: (_, _, _) => fallback,
  );
}

/// 本地图片（自动处理 AVIF）。
Widget displayLocalImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  Widget? fallback,

  /// 网格封面建议 340（170×2 倍率）：默认全尺寸解码，上千像素封面内存浪费一个数量级
  int? cacheWidth,
}) {
  final error = fallback ?? const Icon(Icons.broken_image_outlined);
  return _fileImage(path, fit, error, cacheWidth);
}

/// 远端图片（自动处理 AVIF；经临时缓存）。
/// [proxy] 仅对需要代理的源传入（如 JM CDN）；桶内预签名 URL 应直连，
/// 全局代理会让桶图片在代理不可用时一起失败。
Widget displayUrlImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Widget? fallback,
  String? proxy,
  int? cacheWidth,
}) {
  final error = fallback ?? const Icon(Icons.broken_image_outlined);
  return FutureBuilder<String>(
    future: cacheImageFile(url, proxy: proxy),
    builder: (context, snap) {
      final path = snap.data;
      if (path == null) {
        return fallback ?? const Center(child: CircularProgressIndicator());
      }
      return _fileImage(path, fit, error, cacheWidth);
    },
  );
}

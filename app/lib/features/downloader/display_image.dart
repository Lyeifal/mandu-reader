import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 下载 URL 到临时缓存（按 URL 的 path 哈希，幂等），返回本地路径。
/// key 只取 path：预签名 URL 的 query（X-Amz-Signature 等）每次不同，
/// 参与 key 会让缓存永远不命中。[proxy] 仅供需要代理的源（JM CDN）使用。
Future<String> _cachedFile(String url, {String? proxy}) async {
  final key = md5.convert(utf8.encode(url.split('?').first)).toString();
  final tmp = await getTemporaryDirectory();
  final dir = Directory(p.join(tmp.path, 'mandu_img_cache'));
  await dir.create(recursive: true);
  final ext = p.extension(url.split('?').first);
  final file = File(p.join(dir.path, '$key${ext.isEmpty ? '.bin' : ext}'));
  if (await file.exists()) return file.path;

  final client = HttpClient();
  final clean = proxy?.trim() ?? '';
  if (clean.isNotEmpty) {
    client.findProxy = (uri) =>
        'PROXY ${clean.replaceFirst(RegExp('^https?://'), '')}';
  }
  try {
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
  } finally {
    client.close();
  }
}

Widget _fileImage(String path, BoxFit fit, Widget fallback) {
  if (p.extension(path).toLowerCase() == '.avif') {
    return AvifImage.file(
      File(path),
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
  return Image.file(File(path), fit: fit, errorBuilder: (_, _, _) => fallback);
}

/// 本地图片（自动处理 AVIF）。
Widget displayLocalImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  Widget? fallback,
}) {
  final error = fallback ?? const Icon(Icons.broken_image_outlined);
  return _fileImage(path, fit, error);
}

/// 远端图片（自动处理 AVIF；经临时缓存）。
/// [proxy] 仅对需要代理的源传入（如 JM CDN）；桶内预签名 URL 应直连，
/// 全局代理会让桶图片在代理不可用时一起失败。
Widget displayUrlImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Widget? fallback,
  String? proxy,
}) {
  final error = fallback ?? const Icon(Icons.broken_image_outlined);
  return FutureBuilder<String>(
    future: _cachedFile(url, proxy: proxy),
    builder: (context, snap) {
      final path = snap.data;
      if (path == null) {
        return fallback ?? const Center(child: CircularProgressIndicator());
      }
      return _fileImage(path, fit, error);
    },
  );
}

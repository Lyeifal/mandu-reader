import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:minio/minio.dart';

import '../../core/exceptions.dart';
import '../bucket/bucket_client.dart';
import 'bucket_config.dart';
import 'path_helper.dart';

/// 基于 minio pub 包的桶客户端。
///
/// Range GET 说明：minio 3.5.8 的 getObject 不支持 offset，
/// 但其预签名仅签 host 头，因此用「预签名 URL + 自带 Range 头」实现区间读，
/// 对 S3 / MinIO / R2 / OSS / COS 均合法（SigV4 允许未列名的额外请求头）。
class MinioBucketClient implements BucketClient {
  MinioBucketClient(this.config, {http.Client? httpClient})
    : _http = httpClient ?? http.Client() {
    config.validate();
    _minio = Minio(
      endPoint: config.endpoint,
      port: config.port,
      useSSL: config.useSSL,
      accessKey: config.accessKey,
      secretKey: config.secretKey,
      region: config.region.isEmpty ? null : config.region,
    );
  }

  final BucketConfig config;
  final http.Client _http;
  late final Minio _minio;

  static const _maxRetries = 3;

  @override
  Future<ConnectivityResult> checkConnectivity() async {
    final sw = Stopwatch()..start();
    try {
      final exists = await _minio.bucketExists(config.bucket);
      if (!exists) {
        throw const ConnectionException('bucket 不存在或无权访问');
      }
      final chunks = await _minio
          .listObjects(
            config.bucket,
            prefix: LibraryPaths.indexPrefix,
            recursive: true,
          )
          .take(1)
          .toList();
      String? indexEtag;
      if (chunks.isNotEmpty && chunks.first.objects.isNotEmpty) {
        final first = chunks.first.objects.first;
        indexEtag = (first as dynamic).eTag as String?;
      }
      return ConnectivityResult(
        ok: true,
        latencyMs: sw.elapsedMilliseconds,
        indexEtag: indexEtag,
        detail: 'bucket=${config.bucket}',
      );
    } on StorageException {
      rethrow;
    } on MinioError catch (e) {
      throw ConnectionException('连接失败: ${e.message}', cause: e);
    }
  }

  @override
  Future<ObjectMeta> stat(String key) async {
    try {
      final r = await _minio.statObject(config.bucket, key);
      return ObjectMeta(
        size: r.size ?? -1,
        etag: r.etag,
        lastModified: r.lastModified,
      );
    } on MinioError catch (e) {
      throw _mapError('stat $key', e);
    }
  }

  @override
  Future<Uint8List> getRange(String key, {int? start, int? end}) async {
    if ((start ?? 0) < 0 || (end != null && end < (start ?? 0))) {
      throw ArgumentError.value('非法区间 [$start, $end)');
    }
    return _withRetry(() async {
      final url = await _minio.presignedGetObject(
        config.bucket,
        key,
        expires: 600,
      );
      final headers = <String, String>{
        if (start != null)
          'range': 'bytes=$start-${end != null ? end - 1 : ''}',
      };
      final resp = await _http
          .get(Uri.parse(url), headers: headers.isEmpty ? null : headers)
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 404 || resp.statusCode == 403) {
        throw ObjectNotFoundException('$key (${resp.statusCode})');
      }
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw ConnectionException('GET $key 返回 ${resp.statusCode}');
      }
      return resp.bodyBytes;
    });
  }

  @override
  Future<Uint8List> getAll(String key) => getRange(key, start: 0);

  @override
  Future<void> put(String key, Uint8List data) async {
    try {
      await _minio.putObject(
        config.bucket,
        key,
        Stream<Uint8List>.value(data),
        size: data.length,
      );
    } on MinioError catch (e) {
      throw _mapError('put $key', e);
    }
  }

  @override
  Future<String> presignGet(
    String key, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    try {
      return await _minio.presignedGetObject(
        config.bucket,
        key,
        expires: ttl.inSeconds,
      );
    } on MinioError catch (e) {
      throw _mapError('presign $key', e);
    }
  }

  @override
  Future<List<String>> listKeys(String prefix, {int max = 20}) async {
    try {
      final keys = <String>[];
      await for (final chunk in _minio.listObjects(
        config.bucket,
        prefix: prefix,
        recursive: true,
      )) {
        for (final o in chunk.objects) {
          keys.add((o as dynamic).key as String);
          if (keys.length >= max) return keys;
        }
      }
      return keys;
    } on MinioError catch (e) {
      throw _mapError('list $prefix', e);
    }
  }

  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    Object? last;
    for (var i = 0; i < _maxRetries; i++) {
      try {
        return await fn();
      } on ObjectNotFoundException {
        rethrow;
      } on Object catch (e) {
        last = e;
        if (i < _maxRetries - 1) {
          await Future<void>.delayed(Duration(milliseconds: 500 << i));
        }
      }
    }
    throw RetryExhaustedException('重试 $_maxRetries 次仍失败', cause: last);
  }

  StorageException _mapError(String op, MinioError e) {
    final msg = e.message ?? '';
    if (msg.contains('Not Found') ||
        msg.contains('NoSuchKey') ||
        msg.contains('404')) {
      return ObjectNotFoundException('$op: $msg', cause: e);
    }
    return ConnectionException('$op: $msg', cause: e);
  }
}

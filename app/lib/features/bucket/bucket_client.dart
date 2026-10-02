import 'dart:typed_data';

/// 对象元信息。
class ObjectMeta {
  const ObjectMeta({required this.size, this.etag, this.lastModified});

  final int size;
  final String? etag;
  final DateTime? lastModified;
}

/// 连接测试结果（设计文档 M1 验收 1）。
class ConnectivityResult {
  const ConnectivityResult({
    required this.ok,
    required this.latencyMs,
    this.indexEtag,
    this.detail = '',
  });

  final bool ok;
  final int latencyMs;
  final String? indexEtag;
  final String detail;
}

/// 桶客户端抽象。实现见 [MinioBucketClient]；测试用 fake 替换。
abstract class BucketClient {
  /// HEAD bucket + 探测 `_index/` 可达性，返回延迟。
  Future<ConnectivityResult> checkConnectivity();

  /// 对象元信息（HEAD）。
  Future<ObjectMeta> stat(String key);

  /// 读取 [start, end) 字节区间（end 为空读到末尾）。
  /// 实现层允许服务端忽略 Range 返回整体，调用方按返回体自行处理。
  Future<Uint8List> getRange(String key, {int? start, int? end});

  /// 整对象读取（= getRange 从 0 开始）。
  Future<Uint8List> getAll(String key) => getRange(key, start: 0);

  /// 上传对象。M1 供 events.jsonl 追加与 tmp-key 写路径使用。
  Future<void> put(String key, Uint8List data);

  /// 预签名 GET URL（防盗链直读，供图片/字体直载）。
  Future<String> presignGet(
    String key, {
    Duration ttl = const Duration(minutes: 5),
  });

  /// 列出 prefix 下的 key（至多 [max] 个）。
  Future<List<String>> listKeys(String prefix, {int max = 20});

  /// 删除单个对象。
  Future<void> delete(String key);
}

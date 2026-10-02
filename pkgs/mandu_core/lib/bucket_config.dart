import 'package:mandu_core/exceptions.dart';

/// 私有桶连接配置（无 scheme 的 endpoint + 显式开关）。
class BucketConfig {
  const BucketConfig({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    this.port,
    this.useSSL = true,
  });

  /// 如 `oss-cn-hangzhou.aliyuncs.com` / `127.0.0.1`。
  final String endpoint;
  final int? port;
  final bool useSSL;
  final String region;
  final String bucket;
  final String accessKey;
  final String secretKey;

  void validate() {
    final missing = <String>[
      if (endpoint.trim().isEmpty) 'endpoint',
      if (bucket.trim().isEmpty) 'bucket',
      if (accessKey.trim().isEmpty) 'accessKey',
      if (secretKey.trim().isEmpty) 'secretKey',
    ];
    if (missing.isNotEmpty) {
      throw BucketConfigException('缺少字段: ${missing.join(', ')}');
    }
  }

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    if (port != null) 'port': port,
    'useSSL': useSSL,
    'region': region,
    'bucket': bucket,
    'accessKey': accessKey,
    // secretKey 不落此 JSON（单独加密存储）
  };

  factory BucketConfig.fromJson(Map<String, dynamic> json) => BucketConfig(
    endpoint: (json['endpoint'] ?? '') as String,
    port: json['port'] as int?,
    useSSL: (json['useSSL'] as bool?) ?? true,
    region: (json['region'] ?? '') as String,
    bucket: (json['bucket'] ?? '') as String,
    accessKey: (json['accessKey'] ?? '') as String,
    secretKey: '',
  );

  BucketConfig copyWith({String? secretKey}) => BucketConfig(
    endpoint: endpoint,
    port: port,
    useSSL: useSSL,
    region: region,
    bucket: bucket,
    accessKey: accessKey,
    secretKey: secretKey ?? this.secretKey,
  );
}

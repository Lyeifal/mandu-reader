import 'dart:convert';
import 'dart:typed_data';

import '../../core/exceptions.dart';
import 'bucket_client.dart';
import 'path_helper.dart';

/// 默认目录初始化结果。
class BucketInitResult {
  const BucketInitResult({required this.created, required this.existed});

  /// 本次创建的对象（展示名）。
  final List<String> created;

  /// 已存在、未改动的对象（展示名）。
  final List<String> existed;

  bool get isNoop => created.isEmpty;
}

/// 首次成功连接桶后确保默认目录结构存在（设计文档 §3）：
/// - `library/_index/works.jsonl`：空索引，让同步免 404
/// - `library/_app/config.json`：初始化配置（喜好标签等跨设备偏好）
class BucketInitializer {
  BucketInitializer(this._client);

  final BucketClient _client;

  static const _initialConfigJson =
      '{"version":1,"favorite_tags":[],"note":"漫读初始化配置；favorite_tags 为喜好标签"}';

  static const _targets = <(String, String, String)>[
    (LibraryPaths.worksIndex, 'works.jsonl', '\n'),
    (LibraryPaths.appConfig, 'config.json', _initialConfigJson),
  ];

  Future<BucketInitResult> ensureDefaults() async {
    final created = <String>[];
    final existed = <String>[];
    for (final (key, label, content) in _targets) {
      try {
        await _client.stat(key);
        existed.add(label);
      } on ObjectNotFoundException {
        await _client.put(key, Uint8List.fromList(utf8.encode(content)));
        created.add(label);
      }
    }
    return BucketInitResult(created: created, existed: existed);
  }
}

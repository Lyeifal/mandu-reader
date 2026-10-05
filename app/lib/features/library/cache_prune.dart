/// 启动缓存修剪（M7 缓存清理策略）。
///
/// 三个目标：
/// - `mandu_img_cache`（图片下载缓存）：按设置 `cache.imageLimitMb` 上限 LRU 淘汰；
/// - `_novel_cache`（云端小说阅读缓存）：固定 512MB 上限 LRU 淘汰（重拉便宜）；
/// - `compress_review` 残留目录（审阅中途被杀会泄漏）：启动时整删。
/// `_font_cache` 刻意不淘汰（字体重拉成本高，且桶内同步是拉缺不删方向）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// 按容量上限 LRU 修剪目录：递归统计体积，按最后访问时间（无效回退修改时间）
/// 升序删文件直至达标；返回释放的字节数。capBytes <= 0 视为不限（不修剪）。
Future<int> pruneDirBySizeLru(Directory dir, int capBytes) async {
  if (capBytes <= 0 || !await dir.exists()) return 0;
  final files = <(File, DateTime, int)>[];
  var total = 0;
  await for (final f in dir.list(recursive: true)) {
    if (f is File) {
      try {
        final st = await f.stat();
        if (st.type != FileSystemEntityType.file) continue;
        total += st.size;
        files.add((f, st.accessed, st.size));
      } on Object {
        // 统计不到的文件跳过（可能被并发删除）
      }
    }
  }
  if (total <= capBytes) return 0;
  files.sort((a, b) => a.$2.compareTo(b.$2));
  var freed = 0;
  for (final entry in files) {
    if (total - freed <= capBytes) break;
    try {
      await entry.$1.delete();
      freed += entry.$3;
    } on Object {
      // 删不掉跳过，下轮启动再试
    }
  }
  return freed;
}

/// 启动一次性修剪。返回释放的总字节数（日志用）。
Future<int> pruneStartupCaches({
  required String tmpPath,
  required String localRoot,
  required int imageCapMb,
}) async {
  var freed = 0;
  freed += await pruneDirBySizeLru(
    Directory(p.join(tmpPath, 'mandu_img_cache')),
    imageCapMb * 1024 * 1024,
  );
  freed += await pruneDirBySizeLru(
    Directory(p.join(localRoot, '_novel_cache')),
    512 * 1024 * 1024,
  );
  try {
    final reviewDir = Directory(p.join(tmpPath, 'compress_review'));
    if (await reviewDir.exists()) await reviewDir.delete(recursive: true);
  } on Object {
    // 残留清不掉不阻塞启动
  }
  return freed;
}

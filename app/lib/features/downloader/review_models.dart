import '../bucket/bucket_client.dart';
import 'cloud_compress.dart' show pageKeysOf;

/// 审阅决定：用 AVIF 替换原图 / 保留原图 / 跳过（下次再审）。
enum ReviewDecision { keepAvif, keepOriginal, skip }

/// 一本作品的页面压缩概况（选书列表用）。
class PageStats {
  const PageStats({
    required this.total,
    required this.raw,
    required this.rawBytes,
  });

  /// 数字页面总数（封面/章节表不算）。
  final int total;

  /// 仍为原图（待审）的页数。
  final int raw;

  /// 原图页体积合计（字节），选书时掂量工作量用。
  final int rawBytes;

  bool get hasPending => raw > 0;

  /// 已压成 AVIF 的页数。
  int get avif => total - raw;
}

/// 从对象列举算页面概况（纯函数，单测对象）。
PageStats summarizePages(List<BucketObjectInfo> objects) {
  final keys = objects.map((e) => e.key).toList();
  final pages = pageKeysOf(keys);
  final rawKeys = pages.where((k) => !k.endsWith('.avif')).toSet();
  var rawBytes = 0;
  for (final o in objects) {
    if (rawKeys.contains(o.key)) rawBytes += o.size;
  }
  return PageStats(
    total: pages.length,
    raw: rawKeys.length,
    rawBytes: rawBytes,
  );
}

/// 待审目标：桶里一页非 AVIF 原图。
class ReviewTarget {
  const ReviewTarget({required this.key, required this.isFirstPage});

  final String key;
  final bool isFirstPage;
}

/// 已就绪的一页审阅素材：原图与 AVIF 候选都落在本地临时文件，
/// 展示层只管路径；决定后由驱动层清理。
class ReviewItem {
  const ReviewItem({
    required this.target,
    required this.originalPath,
    required this.avifPath,
    required this.originalBytes,
    required this.avifBytes,
  });

  final ReviewTarget target;
  final String originalPath;
  final String avifPath;
  final int originalBytes;
  final int avifBytes;

  /// 体积节省比例 0..1（原图为 0 字节时按 0）。
  double get saving => originalBytes <= 0 ? 0 : 1 - avifBytes / originalBytes;
}

/// 待审页面 = 三位数字命名的页面里的非 AVIF（封面/章节表/已压的不算）。
List<String> pendingPageKeys(List<String> keys) {
  final pages = pageKeysOf(keys);
  return pages.where((k) => !k.endsWith('.avif')).toList();
}

/// 体积人类可读：< 1MB 用 KB，否则 MB 一位小数。
String formatSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// 竖线对比的分割比例钳制：留 2% 边距，避免完全贴边看不见分界线。
double clampSplit(double f) => f.clamp(0.02, 0.98);

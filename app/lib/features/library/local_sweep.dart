import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';

/// 本会话清扫/修剪是否已执行（JM/书源两个任务 notifier 启动恢复都会
/// 触发，调用方先用 [markHousekeepingRan] 判重，I/O 不翻倍）。
bool _housekeepingRan = false;

bool get housekeepingPending => !_housekeepingRan;

void markHousekeepingRan() => _housekeepingRan = true;

/// 本地作品清扫判定（纯函数，单测对象）。
enum LocalWorkFix { keep, remove, repair }

/// [dirExists] 本地目录是否存在；[imageCount]/[hasBookTxt] 目录内的可读
/// 内容计数；[halfRegistered] 行是半成品（下载早期元数据回调登记的
/// pages=0 / 无封面，见 JmPipeline.registerLocal 的 insertOnly 路径）。
LocalWorkFix classifyLocalWork({
  required String type,
  required bool dirExists,
  required int imageCount,
  required bool hasBookTxt,
  required bool halfRegistered,
}) {
  if (!dirExists) return LocalWorkFix.remove;
  if (type == 'manga') {
    if (imageCount == 0) return LocalWorkFix.remove;
  } else if (!hasBookTxt) {
    return LocalWorkFix.remove;
  }
  if (halfRegistered) return LocalWorkFix.repair;
  return LocalWorkFix.keep;
}

const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif', '.bmp'};

/// 清扫本地下载的半成品记录：下载中断/应用被杀留下的「行还在、文件没了」
/// 的 localOnly 作品（点开必报错）；文件健在但行是半成品时补齐字段。
///
/// [activeWorkIds] 是进行中下载任务的 work id（`jm_<albumId>`）：它们的
/// 本地目录在下载完成前还不存在，必须排除，否则会把正在下载的作品误删。
/// 返回 (移除数, 修复数)。
Future<({int removed, int repaired})> sweepDanglingLocalWorks(
  AppDatabase db,
  String root, {
  required Set<String> activeWorkIds,
}) async {
  final rows = await (db.select(
    db.works,
  )..where((t) => t.localOnly.equals(true))).get();
  // 存储目录切换（设置 → 本地下载目录）后，旧作品仍在默认根：两处都算「存在」。
  // 单测等无 Flutter binding 的环境拿不到文档目录——跳过回退（不影响主判定）。
  String? defaultRoot;
  try {
    defaultRoot = p.join(
      (await getApplicationDocumentsDirectory()).path,
      'local_works',
    );
  } on Object {
    defaultRoot = null;
  }
  var removed = 0;
  var repaired = 0;
  for (final w in rows) {
    if (activeWorkIds.contains(w.id)) continue;
    var dir = Directory(p.join(root, w.id));
    var dirExists = await dir.exists();
    if (!dirExists && defaultRoot != null && root != defaultRoot) {
      // 自定义根没有 → 回退默认根找（上传流程同款回退语义，
      // 否则切换存储目录会把旧作品全判成悬挂记录删行）
      final fallback = Directory(p.join(defaultRoot, w.id));
      if (await fallback.exists()) {
        dir = fallback;
        dirExists = true;
      }
    }
    final pages = <String>[];
    var hasBookTxt = false;
    if (dirExists) {
      await for (final e in dir.list()) {
        if (e is! File) continue;
        if (w.type == 'manga' &&
            _imageExts.contains(p.extension(e.path).toLowerCase())) {
          pages.add(e.path);
        } else if (w.type == 'novel' && p.basename(e.path) == 'book.txt') {
          hasBookTxt = true;
        }
      }
      pages.sort();
    }
    final halfManga =
        w.type == 'manga' &&
        (w.pages == null || w.pages == 0 || (w.cover ?? '').isEmpty);
    switch (classifyLocalWork(
      type: w.type,
      dirExists: dirExists,
      imageCount: pages.length,
      hasBookTxt: hasBookTxt,
      halfRegistered: halfManga,
    )) {
      case LocalWorkFix.remove:
        await (db.delete(db.works)..where((t) => t.id.equals(w.id))).go();
        await db.customStatement('DELETE FROM works_fts WHERE id = ?', [w.id]);
        await (db.delete(
          db.bookmarks,
        )..where((t) => t.workId.equals(w.id))).go();
        await (db.delete(
          db.readingProgress,
        )..where((t) => t.workId.equals(w.id))).go();
        removed++;
      case LocalWorkFix.repair:
        // 行是早期元数据回调登记的半成品，目录已完整：补齐页数与封面
        await (db.update(db.works)..where((t) => t.id.equals(w.id))).write(
          WorksCompanion(
            pages: Value(pages.length),
            cover: Value(p.basename(pages.first)),
            syncedAt: Value(DateTime.now()),
          ),
        );
        repaired++;
      case LocalWorkFix.keep:
    }
  }
  return (removed: removed, repaired: repaired);
}

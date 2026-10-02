import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/exceptions.dart';
import '../../data/db/app_database.dart';
import '../bucket/path_helper.dart';
import '../downloader/jm_pipeline.dart';
import '../providers.dart';

/// 删除本设备上与作品相关的文件：本地作品目录 + 云端小说的阅读缓存。
/// 书架记录保留（localOnly 作品删除后将无法阅读，调用方需先向用户确认）。
Future<void> deleteLocalWorkFiles(WidgetRef ref, Work work) async {
  final root = await resolveLocalRoot(ref.read(settingsRepositoryProvider));
  final dirs = [
    Directory(p.join(root, work.id)),
    Directory(p.join(root, '_novel_cache', work.id)),
  ];
  for (final d in dirs) {
    if (await d.exists()) await d.delete(recursive: true);
  }
  // 仅本设备作品：文件删了记录留着也打不开，连书架记录一起移除
  if (work.localOnly) {
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.works)..where((t) => t.id.equals(work.id))).go();
    await db.customStatement('DELETE FROM works_fts WHERE id = ?', [work.id]);
  }
}

/// 作品在桶里的目录：与阅读器定位逻辑一致（cover 所在目录；
/// 小说可按路径规则推导，漫画必须有 cover）。
String? cloudDirOf(Work work) {
  final cover = work.cover;
  if (cover != null && cover.isNotEmpty) return p.dirname(cover);
  if (work.type == 'novel') {
    return LibraryPaths.novelDir(
      author: work.author,
      series: work.series,
      title: work.title,
    );
  }
  return null;
}

/// 从云端删除作品。顺序有讲究：先写索引墓碑、再处理本地记录（这两步
/// 必须完成，否则留下「记录还在、云端没了」的空壳），最后删桶里对象
/// （逐 key 容错，失败汇总抛出以便重试；墓碑已写，重试安全）。
Future<void> deleteWorkFromCloud(WidgetRef ref, Work work) async {
  final client = ref.read(bucketClientProvider);
  if (client == null) throw StateError('桶客户端不可用');
  final dir = cloudDirOf(work);
  if (dir == null) {
    throw StateError('缺少 cover 字段，无法定位云端目录');
  }
  // 1) 索引里移除该 id 的旧行，并追加墓碑行——其他设备同步时据此处置本地记录
  final existing = utf8.decode(
    await client.getAll(LibraryPaths.worksIndex),
    allowMalformed: true,
  );
  final lines = existing.split('\n').where((e) => e.trim().isNotEmpty).where((
    line,
  ) {
    try {
      return (jsonDecode(line) as Map)['id'] != work.id;
    } on Object {
      return true;
    }
  }).toList()..add(jsonEncode({'id': work.id, 'deleted': true}));
  await client.put(
    LibraryPaths.worksIndex,
    Uint8List.fromList(utf8.encode('${lines.join('\n')}\n')),
  );
  // 2) 本地记录：本地有文件（含小说阅读缓存转正）→ 转「仅本设备」；否则整行删掉
  final root = await resolveLocalRoot(ref.read(settingsRepositoryProvider));
  final hasLocal = await ensureLocalCopy(root, work.id);
  final db = ref.read(appDatabaseProvider);
  if (hasLocal) {
    await (db.update(db.works)..where((t) => t.id.equals(work.id))).write(
      const WorksCompanion(localOnly: Value(true)),
    );
  } else {
    await (db.delete(db.works)..where((t) => t.id.equals(work.id))).go();
    await db.customStatement('DELETE FROM works_fts WHERE id = ?', [work.id]);
  }
  // 3) 删桶里对象：逐 key 容错，有失败汇总后抛出（索引已墓碑化，重试安全）
  final keys = await client.listKeys(dir, max: 5000);
  final failed = <String>[];
  for (final key in keys) {
    try {
      await client.delete(key);
    } on Object {
      failed.add(key);
    }
  }
  if (failed.isNotEmpty) {
    throw ConnectionException(
      '云端对象未删干净（${failed.length}/${keys.length} 个失败），再点一次删除云端重试',
    );
  }
}

/// 确认某作品在本机是否有可读副本；若有云端小说的阅读缓存则转正为本地目录
/// （`<root>/<id>/`），保证转成 localOnly 后阅读器找得到文件。
/// 返回转正/确认后的结果：true = 本地确有副本。
Future<bool> ensureLocalCopy(String root, String workId) async {
  final local = Directory(p.join(root, workId));
  if (await local.exists()) return true;
  final cache = Directory(p.join(root, '_novel_cache', workId));
  if (await cache.exists()) {
    await cache.rename(local.path);
    return true;
  }
  return false;
}

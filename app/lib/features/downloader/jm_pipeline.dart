import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/index_merge.dart';
import '../../core/retry.dart';
import '../../data/db/app_database.dart';
import '../bucket/bucket_client.dart';
import '../bucket/path_helper.dart';
import '../jm/jm_downloader.dart';
import '../settings/settings_repository.dart';
import 'avif_transcoder.dart';
import 'jm_models.dart';

/// 下载阶段的落盘结果（尚未上传）。
class JmLocalResult {
  const JmLocalResult({
    required this.meta,
    required this.pageCount,
    required this.localDir,
    this.keptOriginal = 0,
  });

  final JmAlbumMeta meta;
  final int pageCount;

  /// 本地缓存根目录下 `<id>/`（页面按 `NNN.<ext>` 命名）。
  final String localDir;

  /// 压缩判定后保留的原图页数。
  final int keptOriginal;
}

/// 默认本地缓存根：应用文档目录下 local_works/。
Future<String> defaultLocalRoot() async {
  final docs = await getApplicationDocumentsDirectory();
  return p.join(docs.path, 'local_works');
}

/// 解析本地缓存根：设置项 storage.local_dir 优先，空则默认目录。
Future<String> resolveLocalRoot(SettingsRepository repo) async {
  final custom = (await repo.get('storage.local_dir'))?.trim() ?? '';
  return custom.isEmpty ? defaultLocalRoot() : custom;
}

/// JM 下载 → AVIF 压缩 → 本地登记（local_only）。上传独立决定：
/// 详情页「上传到云端」走 [upload]，即设计文档 §8.3 的「上传归档」流程。
class JmPipeline {
  JmPipeline({JmTranscoder? transcoder, this.localRoot})
    : transcoder = transcoder ?? AvifTranscoder();

  final JmTranscoder transcoder;

  /// 本地缓存根（绝对路径）。为空时按 [resolveLocalRoot] 逻辑回落。
  final String? localRoot;

  Future<String> _resolveRoot() async => localRoot ?? await defaultLocalRoot();

  // ---------------------------------------------------------------- 下载

  Future<JmLocalResult> download({
    required String albumId,
    String proxy = '',
    void Function(JmAlbumMeta meta)? onMeta,
    void Function(JmLocalResult result)? onLocalReady,
    void Function(int done, int total, int kept)? onCompressProgress,
    required void Function(String phase) onProgress,
  }) async {
    onProgress('准备下载…');
    final tmp = await getTemporaryDirectory();
    final workDir = Directory(p.join(tmp.path, 'jm_download', 'jm_$albumId'));
    await workDir.create(recursive: true);
    try {
      // 纯 Dart 下载：详情 + 并发拉图 + scramble 还原（不再需要 Python）
      final result = await JmDartDownloader(proxy: proxy)
          .download(albumId, workDir.path, onProgress: onProgress);
      final meta = result.meta;
      onMeta?.call(meta);

      // 1) 原图立即落本地目录——不等压缩，用户马上可读
      onProgress('原图入库 ${result.files.length} 页…');
      final localDir = await _copyToLocal(
        'jm_${meta.albumId}',
        result.files,
        await _resolveRoot(),
        (_) {},
      );
      onLocalReady?.call(
        JmLocalResult(
          meta: meta,
          pageCount: result.files.length,
          localDir: localDir,
        ),
      );

      // 2) 逐页 AVIF 压缩并就地替换（压完一页换一页）
      final swap = await _compressAndSwap(
        meta,
        localDir,
        onCompressProgress,
        onProgress,
      );

      return JmLocalResult(
        meta: meta,
        pageCount: swap.total,
        localDir: localDir,
        keptOriginal: swap.kept,
      );
    } finally {
      // 原图已拷入本地目录，临时工作目录整体清掉
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  /// 逐页转 AVIF；成功的替换掉本地原图，失败/无收益的保留原图。
  /// 无可用 ffmpeg（手机端常态）时整段跳过：保留原图，稍后由 PC 端压缩云端。
  Future<({int total, int kept})> _compressAndSwap(
    JmAlbumMeta meta,
    String localDir,
    void Function(int done, int total, int kept)? onProgress2,
    void Function(String) onProgress,
  ) async {
    final files = await _listPages(localDir);
    var count = files.length;
    if (!await transcoder.available()) {
      onProgress('未检测到 ffmpeg，跳过压缩（保留原图，可在 PC 端压缩云端）');
      return (total: count, kept: files.length);
    }
    var kept = 0;
    for (var i = 0; i < files.length; i++) {
      final src = files[i];
      if (p.extension(src).toLowerCase() == '.avif') continue;
      onProgress('AVIF 压缩 ${i + 1}/${files.length}（《${meta.title}》）');
      final tmp = p.setExtension(src, '.tmp.avif');
      try {
        // 瞬时错误（ffmpeg 偶发崩溃等）自动重试；确定性失败（无 ffmpeg）直接放过
        final swapped = await withRetry<bool>(
          () => _transcodePage(transcoder, src, tmp),
          shouldRetry: (e) => !isProcessLevelError(e),
          onRetry: (e, attempt) =>
              onProgress('第 ${i + 1} 页转码失败，重试第 $attempt 次…'),
        );
        if (!swapped) kept++;
        onProgress2?.call(i + 1, files.length, kept);
      } on Object catch (e) {
        // 重试期间 tmp 可能从未生成，删除前先看是否存在
        if (await File(tmp).exists()) await File(tmp).delete();
        // 进程级错误（无 ffmpeg，手机端常态）：剩余页全部保留原图并结束
        if (isProcessLevelError(e)) {
          kept += files.length - i;
          onProgress('未检测到可用 ffmpeg，跳过压缩（保留原图）');
          break;
        }
        // 单页重试后仍失败（坏图/参数不支持等）：保留这一页原图，继续后面
        kept++;
        onProgress('第 ${i + 1} 页转码失败，保留原图（${e.toString().split('\n').first}）');
        continue;
      }
    }
    if (kept > 0) onProgress('$kept 页压缩不划算，保留原图');
    return (total: count, kept: kept);
  }

  /// 登记/更新本地作品行（local_only）。幂等：同 id 覆盖。
  /// [JmLocalResult.localDir] 为空时（下载刚拿到元数据）跳过封面探测。
  /// [insertOnly] 为 true 时只在行不存在时插入——下载早期的元数据回调用，
  /// 避免把已有行的 pages/cover 覆盖成半成品（页数 0、无封面）。
  Future<void> registerLocal(
    AppDatabase db,
    JmLocalResult result, {
    bool insertOnly = false,
  }) async {
    final meta = result.meta;
    final first = result.localDir.isEmpty
        ? null
        : await _firstPageFile(result.localDir);
    final companion = WorksCompanion(
      id: Value('jm_${meta.albumId}'),
      type: const Value('manga'),
      title: Value(meta.title),
      author: Value(meta.author),
      series: Value(meta.series),
      volume: const Value(1),
      status: const Value('completed'),
      tags: Value(jsonEncode(meta.tags)),
      pages: Value(result.pageCount),
      hasZh: const Value(true),
      zhQuality: const Value('medium'),
      publishedAt: Value(jmMonth(meta.pubDate) ?? jmMonth(_today())),
      completedAt: Value(jmMonth(meta.updateDate) ?? jmMonth(_today())),
      lastUpdated: Value(_today()),
      cover: Value(first ?? ''),
      origin: const Value('source:jmcomic'),
      localOnly: const Value(true),
      syncedAt: Value(DateTime.now()),
    );
    if (insertOnly) {
      await db.into(db.works).insert(companion, onConflict: DoNothing());
    } else {
      await db.into(db.works).insertOnConflictUpdate(companion);
    }
  }

  // ---------------------------------------------------------------- 上传

  /// 把本地作品上传归档：页面+cover 传桶、追加 works.jsonl、行转非本地。
  Future<String> upload({
    required AppDatabase db,
    required BucketClient client,
    required Work work,
    required void Function(String phase) onProgress,
  }) async {
    final root = await _resolveRoot();
    var dir = Directory(p.join(root, work.id));
    if (!await dir.exists() && root != await defaultLocalRoot()) {
      // 自定义目录下没有，回退默认目录找（历史下载兼容）
      dir = Directory(p.join(await defaultLocalRoot(), work.id));
    }
    if (!await dir.exists()) {
      throw StateError('本地目录不存在：${dir.path}');
    }
    final files = await _listPages(dir.path);
    if (files.isEmpty) throw StateError('本地目录中没有页面文件');

    final author = work.author.isEmpty ? '佚名' : work.author;
    final bucketDir = LibraryPaths.mangaDir(
      author: author,
      series: work.series,
      title: work.title,
      volume: work.volume ?? 1,
    );
    for (var i = 0; i < files.length; i++) {
      onProgress('上传 ${i + 1}/${files.length} 到桶…');
      final ext = p.extension(files[i]).replaceFirst('.', '');
      final key = LibraryPaths.mangaPage(bucketDir, i + 1, ext: ext);
      await client.put(key, await File(files[i]).readAsBytes());
    }
    final firstExt = p.extension(files.first).replaceFirst('.', '');
    final coverKey = '$bucketDir/cover.$firstExt';
    await client.put(coverKey, await File(files.first).readAsBytes());

    await _appendIndex(
      client,
      work,
      files.length,
      bucketDir,
      coverKey,
      files.every((f) => p.extension(f).toLowerCase() == '.avif'),
    );
    await (db.update(db.works)..where((t) => t.id.equals(work.id))).write(
      WorksCompanion(localOnly: const Value(false), cover: Value(coverKey)),
    );
    return bucketDir;
  }

  /// 小说上传归档：book.txt（必需）+ 封面 + chapters.json 传桶，
  /// 追加索引行（novel 用 total_chars，漫画用 pages）。
  Future<String> uploadNovel({
    required AppDatabase db,
    required BucketClient client,
    required Work work,
    required void Function(String phase) onProgress,
  }) async {
    final root = await _resolveRoot();
    var dir = Directory(p.join(root, work.id));
    if (!await dir.exists() && root != await defaultLocalRoot()) {
      // 自定义目录下没有，回退默认目录找（历史下载兼容）
      dir = Directory(p.join(await defaultLocalRoot(), work.id));
    }
    if (!await dir.exists()) {
      throw StateError('本地目录不存在：${dir.path}');
    }
    final txt = File(p.join(dir.path, 'book.txt'));
    if (!await txt.exists()) throw StateError('本地目录中没有 book.txt');

    final author = work.author.isEmpty ? '佚名' : work.author;
    final bucketDir = LibraryPaths.novelDir(
      author: author,
      series: work.series,
      title: work.title,
    );
    onProgress('上传 book.txt…');
    await client.put(
      LibraryPaths.novelTxt(
        author: author,
        series: work.series,
        title: work.title,
      ),
      await txt.readAsBytes(),
    );

    var coverKey = '';
    final coverName = work.cover;
    if (coverName != null && coverName.isNotEmpty) {
      final cf = File(p.join(dir.path, coverName));
      if (await cf.exists()) {
        onProgress('上传封面…');
        coverKey = '$bucketDir/${p.basename(coverName)}';
        await client.put(coverKey, await cf.readAsBytes());
      }
    }
    final chapters = File(p.join(dir.path, 'chapters.json'));
    if (await chapters.exists()) {
      onProgress('上传章节表…');
      await client.put(
        '$bucketDir/chapters.json',
        await chapters.readAsBytes(),
      );
    }

    final totalChars = (await txt.readAsString()).length;
    await _appendNovelIndex(client, work, bucketDir, coverKey, totalChars);
    await (db.update(db.works)..where((t) => t.id.equals(work.id))).write(
      WorksCompanion(
        localOnly: const Value(false),
        cover: Value(coverKey.isEmpty ? work.cover : coverKey),
      ),
    );
    return bucketDir;
  }

  // ---------------------------------------------------------------- 内部

  Future<List<String>> _listPages(String root) async {
    final exts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif'};
    final files = <String>[];
    await for (final entity in Directory(root).list(recursive: true)) {
      if (entity is File &&
          exts.contains(p.extension(entity.path).toLowerCase())) {
        files.add(entity.path);
      }
    }
    files.sort();
    return files;
  }

  Future<String> _copyToLocal(
    String workId,
    List<String> pages,
    String root,
    void Function(String) onProgress,
  ) async {
    final dir = Directory(p.join(root, workId));
    // 旧的本地目录直接清掉重铺（重复下载同一车号时保持一致）
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    for (var i = 0; i < pages.length; i++) {
      onProgress('整理本地文件 ${i + 1}/${pages.length}…');
      final ext = p.extension(pages[i]).replaceFirst('.', '');
      final name = '${(i + 1).toString().padLeft(3, '0')}.$ext';
      await File(pages[i]).copy(p.join(dir.path, name));
    }
    return dir.path;
  }

  Future<String?> _firstPageFile(String localDir) async {
    final files = await _listPages(localDir);
    if (files.isEmpty) return null;
    return p.basename(files.first);
  }

  /// 追加/覆写某 id 的漫画索引行（读取-滤旧-写回；同 id 同步时幂等覆盖）。
  /// [compressed] 标记页面是否已全部 AVIF——false 时 PC 端「压缩云端」会接手处理。
  Future<void> _appendIndex(
    BucketClient client,
    Work work,
    int pageCount,
    String dir,
    String coverKey,
    bool compressed,
  ) async {
    await _appendIndexLine(client, <String, Object?>{
      'id': work.id,
      'type': work.type,
      'title': work.title,
      'author': work.author,
      'series': work.series,
      'volume': work.volume,
      'tags': (jsonDecode(work.tags) as List?) ?? const [],
      'status': work.status,
      'pages': pageCount,
      'last_updated': _today(),
      'cover': coverKey,
      'origin': work.origin,
      'local_only': false,
      'has_zh': work.hasZh,
      'zh_quality': work.zhQuality,
      'published_at': work.publishedAt,
      'completed_at': work.completedAt,
      'compressed': compressed,
    });
  }

  /// 小说索引行：novel 的检索字段是 total_chars（无 pages）。
  Future<void> _appendNovelIndex(
    BucketClient client,
    Work work,
    String dir,
    String coverKey,
    int totalChars,
  ) async {
    await _appendIndexLine(client, <String, Object?>{
      'id': work.id,
      'type': 'novel',
      'title': work.title,
      'author': work.author,
      'series': work.series,
      'volume': work.volume,
      'tags': (jsonDecode(work.tags) as List?) ?? const [],
      'status': work.status,
      'total_chars': totalChars,
      'last_updated': _today(),
      if (coverKey.isNotEmpty) 'cover': coverKey,
      'origin': work.origin,
      'local_only': false,
      'has_zh': work.hasZh,
      'zh_quality': work.zhQuality,
      'published_at': work.publishedAt,
      'completed_at': work.completedAt,
    });
  }

  Future<void> _appendIndexLine(
    BucketClient client,
    Map<String, Object?> entry,
  ) async {
    final existing = utf8.decode(
      await client.getAll(LibraryPaths.worksIndex),
      allowMalformed: true,
    );
    await client.put(
      LibraryPaths.worksIndex,
      Uint8List.fromList(utf8.encode(mergeIndexLine(existing, entry))),
    );
  }

  static String _today() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }
}

/// 进程级错误（ffmpeg 不存在/起不来进程）：确定性失败，重试无意义——
/// 命中时整个压缩阶段直接放弃，剩余页全保留原图。纯函数，单测对象。
bool isProcessLevelError(Object e) {
  final msg = e.toString();
  return e is ProcessException ||
      e is FileSystemException ||
      msg.contains('ProcessException') ||
      msg.contains('Cannot run');
}

/// 转码单页并按判定就地替换：返回 true 已换成 .avif，false 不划算保留原图。
/// 转码未产出视为失败抛 StateError（由调用方决定重试或放弃）。
Future<bool> _transcodePage(
  JmTranscoder transcoder,
  String src,
  String tmp,
) async {
  // 压完再判：明显变小且画质损失可接受才替换原图；
  // webp 源本身已是高压缩格式，阈值放宽到省 20% 即换
  final isWebp = p.extension(src).toLowerCase() == '.webp';
  if (!await transcoder.transcode(src, tmp)) {
    throw StateError('ffmpeg 未产出 AVIF');
  }
  final s = await transcoder.ssim(src, tmp);
  final inLen = await File(src).length();
  final outLen = await File(tmp).length();
  if (!worthReplacing(
    inLen,
    outLen,
    s,
    minSaving: isWebp ? 0.20 : 0.30,
    strictSaving: isWebp ? 0.20 : 0.40,
  )) {
    await File(tmp).delete();
    return false;
  }
  await File(src).delete();
  await File(tmp).rename(p.setExtension(src, '.avif'));
  return true;
}

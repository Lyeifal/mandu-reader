import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/retry.dart';
import '../../data/db/app_database.dart';
import '../bucket/bucket_client.dart';
import '../bucket/path_helper.dart';
import 'avif_transcoder.dart';

/// 单页压缩结果（重试闭包产出，供进度文案与封面替换取用）。
class _PageResult {
  const _PageResult({
    required this.replaced,
    required this.inLen,
    required this.outLen,
    this.ssim,
    this.avif,
  });

  /// true = 已传 AVIF 并删原图；false = 不划算保留原图。
  final bool replaced;
  final int inLen;
  final int outLen;
  final double? ssim;
  final Uint8List? avif;
}

/// PC 端「压缩云端」结果汇总。
class CloudCompressReport {
  /// 本次确有非 AVIF 页面、参与压缩的作品数。
  int scanned = 0;

  /// 页面已全部 AVIF、无需处理的作品数。
  int allAvif = 0;

  /// 成功替换为 AVIF 的页数。
  int compressed = 0;

  /// 压缩不划算、保留原图的页数。
  int keptOriginal = 0;

  /// 失败的操作数（下载/转码/传删任一步异常）。
  int failed = 0;
}

/// 从对象 key 列表挑出三位数字命名的漫画页（cover/chapters 等不算）。
/// 纯函数，单测对象。
List<String> pageKeysOf(List<String> keys) {
  final re = RegExp(r'/(\d{3})\.\w+$');
  return keys.where(re.hasMatch).toList()..sort();
}

/// PC 端压缩云端漫画：扫本地书架里所有云端漫画（local_only=false），
/// 对桶里仍非 AVIF 的页面执行 下载 → AVIF 转码 → 判定 → 替换/保留，
/// 最后回写 works.jsonl 的 compressed 标记（封面被替换时一并换 cover）。
///
/// 手机端下载的漫画没 ffmpeg 时保留原图直接上传，由这里兜底压缩。
Future<CloudCompressReport> compressCloudMangas({
  required AppDatabase db,
  required BucketClient client,
  required String ffmpegPath,
  void Function(String phase)? onProgress,
}) async {
  final transcoder = AvifTranscoder(ffmpegPath: ffmpegPath);
  if (!await transcoder.available()) {
    throw StateError('ffmpeg 不可用，请先在设置页填写本机 ffmpeg 路径（仅桌面端可用）');
  }
  final rows = await (db.select(
    db.works,
  )..where((t) => t.type.equals('manga'))).get();
  final cloud = rows.where((w) => !w.localOnly).toList();

  final tmpRoot = Directory(
    p.join((await getTemporaryDirectory()).path, 'cloud_compress'),
  );
  await tmpRoot.create(recursive: true);
  final report = CloudCompressReport();
  try {
    for (final work in cloud) {
      final cover = work.cover;
      if (cover == null || cover.isEmpty) continue;
      // cover 可能不带 library/ 前缀（设计文档 §4.1 示例），读取侧归一
      final coverNorm = LibraryPaths.normalizeKey(cover);
      final dir = p.dirname(coverNorm);
      onProgress?.call('扫描《${work.title}》');
      final List<String> keys;
      try {
        keys = await withRetry(() => client.listKeys(dir, max: 5000));
      } on Object {
        report.failed++;
        continue;
      }
      final pages = pageKeysOf(keys);
      final pending = pages.where((k) => !k.endsWith('.avif')).toList();
      if (pending.isEmpty) {
        report.allAvif++;
        continue;
      }
      report.scanned++;

      final firstExt = p.extension(pages.first).toLowerCase();
      final coverDerived = coverNorm == '$dir/cover$firstExt';
      Uint8List? firstPageAvif; // 首页新 AVIF 字节，用于换封面
      var touched = false;
      var workCompressed = 0;

      for (final key in pending) {
        final name = p.basename(key);
        final ext = p.extension(key).toLowerCase();
        onProgress?.call('压缩《${work.title}》$name');
        final src = File(p.join(tmpRoot.path, 's_${work.id}_$name'));
        final out = File(
          p.join(
            tmpRoot.path,
            'o_${work.id}_${p.basenameWithoutExtension(key)}.avif',
          ),
        );
        try {
          final r = await withRetry<_PageResult>(
            () async {
              // 每轮重试都重新下载页面，避免上一次残留字节影响转码
              await src.writeAsBytes(await client.getAll(key));
              if (!await transcoder.transcode(src.path, out.path)) {
                throw StateError('ffmpeg 未产出 AVIF');
              }
              final s = await transcoder.ssim(src.path, out.path);
              final inLen = await src.length();
              final outLen = await out.length();
              final isWebp = ext == '.webp';
              if (!worthReplacing(
                inLen,
                outLen,
                s,
                minSaving: isWebp ? 0.20 : 0.30,
                strictSaving: isWebp ? 0.20 : 0.40,
              )) {
                return _PageResult(
                  replaced: false,
                  inLen: inLen,
                  outLen: outLen,
                  ssim: s,
                );
              }
              final bytes = await out.readAsBytes();
              await client.put(p.setExtension(key, '.avif'), bytes);
              await client.delete(key);
              return _PageResult(
                replaced: true,
                inLen: inLen,
                outLen: outLen,
                ssim: s,
                avif: bytes,
              );
            },
            onRetry: (e, attempt) =>
                onProgress?.call('《${work.title}》$name 失败，重试第 $attempt 次…'),
          );
          if (!r.replaced) {
            report.keptOriginal++;
            onProgress?.call(
              '《${work.title}》$name 保留原图'
              '（${(r.inLen / 1024).round()}KB → ${(r.outLen / 1024).round()}KB，'
              'ssim=${r.ssim?.toStringAsFixed(3) ?? '无'}）',
            );
            continue;
          }
          report.compressed++;
          workCompressed++;
          touched = true;
          if (key == pages.first) firstPageAvif = r.avif;
        } on Object {
          report.failed++;
        } finally {
          if (await src.exists()) await src.delete();
          if (await out.exists()) await out.delete();
        }
      }

      // 封面是从首页派生的（cover.<首页扩展名>）且首页已换 AVIF → 封面跟随
      String? newCoverKey;
      final firstAvif = coverDerived ? firstPageAvif : null;
      if (firstAvif != null) {
        final coverAvif = '$dir/cover.avif';
        try {
          // put 幂等、delete 忽略不存在，失败可安全重放
          await withRetry(() async {
            await client.put(coverAvif, firstAvif);
            if (coverNorm != coverAvif) await client.delete(coverNorm);
          });
          newCoverKey = coverAvif;
          touched = true;
        } on Object {
          report.failed++;
        }
      }

      if (touched) {
        final stillRaw = pending.length - workCompressed;
        await _rewriteIndex(
          client,
          work,
          pages.length,
          newCoverKey ?? coverNorm,
          stillRaw <= 0,
        );
        await (db.update(db.works)..where((t) => t.id.equals(work.id))).write(
          WorksCompanion(cover: Value(newCoverKey ?? coverNorm)),
        );
      }
    }
  } finally {
    if (await tmpRoot.exists()) await tmpRoot.delete(recursive: true);
  }
  return report;
}

/// 覆写某 id 的索引行（同删除云端的墓碑式重写：滤旧行 + 追加新行）。
Future<void> _rewriteIndex(
  BucketClient client,
  Work work,
  int pageCount,
  String coverKey,
  bool compressed,
) async {
  final existing = utf8.decode(
    await client.getAll(LibraryPaths.worksIndex),
    allowMalformed: true,
  );
  final lines =
      existing.split('\n').where((e) => e.trim().isNotEmpty).where((line) {
        try {
          return (jsonDecode(line) as Map)['id'] != work.id;
        } on Object {
          return true;
        }
      }).toList()..add(
        jsonEncode({
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
        }),
      );
  await client.put(
    LibraryPaths.worksIndex,
    Uint8List.fromList(utf8.encode('${lines.join('\n')}\n')),
  );
}

String _today() {
  final n = DateTime.now();
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '${n.year}-$m-$d';
}

/// 云端压缩任务状态：书架页横幅常驻展示进度/结果/重试入口，
/// 任务在后台跑（切换页面不中断），取代一闪而过的 SnackBar。
class CloudCompressState {
  const CloudCompressState({
    this.running = false,
    this.phase = '',
    this.report,
    this.error,
  });

  final bool running;
  final String phase;
  final CloudCompressReport? report;

  /// 终态错误（运行失败），与 report 互斥。
  final String? error;
}

class _CloudCompressNotifier extends Notifier<CloudCompressState> {
  @override
  CloudCompressState build() => const CloudCompressState();

  Future<void> start({
    required AppDatabase db,
    required BucketClient client,
    required String ffmpegPath,
  }) async {
    if (state.running) return; // 任务串行，防重入
    state = const CloudCompressState(running: true, phase: '准备压缩…');
    try {
      final report = await compressCloudMangas(
        db: db,
        client: client,
        ffmpegPath: ffmpegPath,
        onProgress: (p) => state = CloudCompressState(running: true, phase: p),
      );
      state = CloudCompressState(report: report);
    } on Object catch (e) {
      state = CloudCompressState(
        error: e.toString().replaceFirst('StateError: ', ''),
      );
    }
  }

  void clear() => state = const CloudCompressState();
}

final cloudCompressProvider =
    NotifierProvider<_CloudCompressNotifier, CloudCompressState>(
      _CloudCompressNotifier.new,
    );

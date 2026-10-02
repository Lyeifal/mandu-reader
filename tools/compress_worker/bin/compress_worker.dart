/// 压缩 Worker：常驻进程，轮询桶索引，把未压缩的云端漫画页面转 AVIF。
///
/// 与 App 内「压缩云端漫画」/审阅完全同参数（crf 45 + worthReplacing 阈值），
/// 区别只在选目标：从桶里的 works.jsonl 选（桶即真相），不依赖任何设备的
/// SQLite。手机/PC 传完原图即可，压缩由常开机器兜底。
///
/// 部署（编译为单二进制，宿主只需 ffmpeg）：
///   dart compile exe bin/compress_worker.dart -o compress_worker
///   Linux 服务器：apt install ffmpeg 后挂 systemd（见 README）；
///   Windows：任务计划程序登录触发，或 ONESHOT=1 手动跑。
///
/// 环境变量（必填 *）：
///   BUCKET_ENDPOINT*  BUCKET_NAME*  BUCKET_AK*  BUCKET_SK*
///   BUCKET_REGION（可空）  BUCKET_PORT（可空）  BUCKET_SSL（默认 true）
///   FFMPEG（默认从 PATH 找）  INTERVAL_MINUTES（默认 10）  ONESHOT=1 只跑一轮
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mandu_core/exceptions.dart';
import 'package:mandu_core/index_merge.dart';
import 'package:mandu_core/page_keys.dart';
import 'package:mandu_core/retry.dart';
import 'package:mandu_core/bucket_client.dart';
import 'package:mandu_core/bucket_config.dart';
import 'package:mandu_core/minio_bucket_client.dart';
import 'package:mandu_core/path_helper.dart';
import 'package:mandu_core/avif_transcoder.dart';
import 'package:mandu_core/works_index.dart';
import 'package:path/path.dart' as p;

String _env(String name, {String defaultValue = ''}) =>
    Platform.environment[name]?.trim() ?? defaultValue;

Future<void> main() async {
  final config = BucketConfig(
    endpoint: _env('BUCKET_ENDPOINT'),
    region: _env('BUCKET_REGION'),
    bucket: _env('BUCKET_NAME'),
    accessKey: _env('BUCKET_AK'),
    secretKey: _env('BUCKET_SK'),
    port: int.tryParse(_env('BUCKET_PORT')),
    useSSL: _env('BUCKET_SSL', defaultValue: 'true') != 'false',
  );
  final ffmpeg = _env('FFMPEG', defaultValue: 'ffmpeg');
  final interval =
      int.tryParse(_env('INTERVAL_MINUTES', defaultValue: '10')) ?? 10;
  final oneShot = _env('ONESHOT') == '1';

  try {
    config.validate();
  } on Object catch (e) {
    stderr.writeln('桶配置不完整：$e');
    stderr.writeln(
      '需要环境变量 BUCKET_ENDPOINT / BUCKET_NAME / BUCKET_AK / BUCKET_SK',
    );
    exit(1);
  }

  final client = MinioBucketClient(config);
  final transcoder = AvifTranscoder(ffmpegPath: ffmpeg);
  if (!await transcoder.available()) {
    stderr.writeln('ffmpeg 不可用：$ffmpeg（用 FFMPEG 环境变量指定路径）');
    exit(1);
  }
  stdout.writeln(
    'compress worker up: bucket=${config.bucket} endpoint=${config.endpoint} '
    'interval=${interval}m${oneShot ? ' (oneshot)' : ''}',
  );

  var pass = 0;
  while (true) {
    pass++;
    try {
      await _runPass(client, transcoder, pass);
    } on Object catch (e) {
      stderr.writeln('pass $pass failed: $e');
    }
    if (oneShot) break;
    await Future<void>.delayed(Duration(minutes: interval));
  }
  client.close();
}

Future<void> _runPass(
  BucketClient client,
  AvifTranscoder transcoder,
  int pass,
) async {
  final String content;
  try {
    content = utf8.decode(
      await client.getAll(LibraryPaths.worksIndex),
      allowMalformed: true,
    );
  } on ObjectNotFoundException {
    return; // 索引还没初始化，无可做
  }
  final parsed = parseWorksIndex(content);
  final targets = selectCompressTargets(parsed.entries);
  if (targets.isEmpty) return;
  stdout.writeln('pass $pass: ${targets.length} 本待压缩');

  final tmp = await Directory.systemTemp.createTemp('mandu_compress_worker');
  try {
    for (final w in targets) {
      await _compressWork(client, transcoder, tmp, w);
    }
  } finally {
    await tmp.delete(recursive: true);
  }
}

class _PageResult {
  const _PageResult(this.replaced, {this.bytes});

  final bool replaced;
  final Uint8List? bytes;
}

Future<void> _compressWork(
  BucketClient client,
  AvifTranscoder transcoder,
  Directory tmp,
  WorksIndexEntry w,
) async {
  final cover = w.cover;
  if (cover == null || cover.isEmpty) {
    stdout.writeln('  《${w.title}》 跳过：索引行缺 cover，无法定位目录');
    return;
  }
  final dir = p.dirname(LibraryPaths.normalizeKey(cover));
  final List<String> keys;
  try {
    keys = await withRetry(() => client.listKeys(dir, max: 5000));
  } on Object catch (e) {
    stderr.writeln('  《${w.title}》 列目录失败：$e');
    return;
  }
  final pages = pageKeysOf(keys);
  final pending = pages.where((k) => !k.endsWith('.avif')).toList();

  var replaced = 0, kept = 0, failed = 0;
  Uint8List? firstAvif; // 首页新 AVIF 字节，封面跟随用
  for (final key in pending) {
    final name = p.basename(key);
    final src = File(p.join(tmp.path, 's_${w.id}_$name'));
    final out = File(
      p.join(tmp.path, 'o_${w.id}_${p.basenameWithoutExtension(key)}.avif'),
    );
    try {
      final r = await withRetry<_PageResult>(() async {
        // 每轮重试重新下载，避免上一次残留字节影响转码
        await src.writeAsBytes(await client.getAll(key));
        if (!await transcoder.transcode(src.path, out.path)) {
          throw StateError('ffmpeg 未产出 AVIF');
        }
        final s = await transcoder.ssim(src.path, out.path);
        final inLen = await src.length();
        final outLen = await out.length();
        final isWebp = p.extension(key).toLowerCase() == '.webp';
        if (!worthReplacing(
          inLen,
          outLen,
          s,
          minSaving: isWebp ? 0.20 : 0.30,
          strictSaving: isWebp ? 0.20 : 0.40,
        )) {
          return const _PageResult(false);
        }
        final bytes = await out.readAsBytes();
        await client.put(p.setExtension(key, '.avif'), bytes);
        await client.delete(key);
        return _PageResult(true, bytes: bytes);
      });
      if (r.replaced) {
        replaced++;
        if (key == pages.first) firstAvif = r.bytes;
      } else {
        kept++;
      }
    } on Object {
      failed++;
    } finally {
      for (final f in [src, out]) {
        if (await f.exists()) await f.delete();
      }
    }
  }

  // 封面跟随 + 索引回写。即使没有待压页也回写（全 AVIF 的作品补打
  // compressed 标记，后续 pass 直接跳过——自修复，只需一次）。
  final coverNorm = LibraryPaths.normalizeKey(cover);
  var newCover = coverNorm;
  final firstExt = pages.isEmpty ? '' : p.extension(pages.first).toLowerCase();
  final coverDerived = coverNorm == '$dir/cover$firstExt';
  if (coverDerived && firstAvif != null) {
    final coverAvif = '$dir/cover.avif';
    try {
      await withRetry(() async {
        await client.put(coverAvif, firstAvif!);
        if (coverNorm != coverAvif) await client.delete(coverNorm);
      });
      newCover = coverAvif;
    } on Object catch (e) {
      stderr.writeln('  《${w.title}》 封面替换失败：$e');
    }
  }
  final stillRaw = pending.length - replaced;
  await _rewriteIndex(client, w, pages.length, newCover, stillRaw <= 0);
  stdout.writeln(
    '  《${w.title}》 压 $replaced / 留 $kept / 败 $failed → '
    'compressed=${stillRaw <= 0}',
  );
}

/// 回写该作品的索引行（compressed 标记 + 可能的封面更新）。
/// 与 App 侧 rewriteWorkIndex 同构：滤同 id 旧行后整文件写回。
Future<void> _rewriteIndex(
  BucketClient client,
  WorksIndexEntry w,
  int pageCount,
  String cover,
  bool compressed,
) async {
  final existing = utf8.decode(
    await client.getAll(LibraryPaths.worksIndex),
    allowMalformed: true,
  );
  final now = DateTime.now();
  final entry = <String, Object?>{
    'id': w.id,
    'type': w.type,
    'title': w.title,
    'author': w.author,
    'series': w.series,
    'volume': w.volume,
    'tags': w.tags,
    'status': w.status,
    'pages': pageCount,
    'last_updated':
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}',
    'cover': cover,
    'origin': w.origin,
    'local_only': false,
    'has_zh': w.hasZh,
    'zh_quality': w.zhQuality,
    'published_at': w.publishedAt,
    'completed_at': w.completedAt,
    'compressed': compressed,
  };
  await client.put(
    LibraryPaths.worksIndex,
    Uint8List.fromList(utf8.encode(mergeIndexLine(existing, entry))),
  );
}

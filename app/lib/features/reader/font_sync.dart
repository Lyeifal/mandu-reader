import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/retry.dart';
import '../bucket/path_helper.dart';
import '../downloader/jm_pipeline.dart';
import '../providers.dart';
import 'reader_page.dart'; // fontFamilyFor

/// 字体库条目：一个已加载的自定义字体。
class FontEntry {
  const FontEntry({
    required this.fileName,
    required this.family,
    required this.path,
  });

  final String fileName;
  final String family;
  final String path;
}

const _fontExts = {'.ttf', '.otf'};

/// 字体库（设计文档 §7.2）：`library/_fonts/` 是桶内唯一字体库，各设备
/// 拉缺/补缺双向幂等同步；本地缓存 `localRoot/_font_cache/`（与
/// `_novel_cache` 同级，local_sweep 不扫下划线目录）。进入阅读器
/// 首次 watch 本 provider 即自动引导同步，Android 端靠它获得桌面端
/// 导入的字体（SAF 限制无法本地导入）。
final fontLibraryProvider =
    AsyncNotifierProvider<_FontLibraryNotifier, List<FontEntry>>(
      _FontLibraryNotifier.new,
    );

class _FontLibraryNotifier extends AsyncNotifier<List<FontEntry>> {
  @override
  Future<List<FontEntry>> build() => _sync();

  /// 导入/同步后重跑（幂等：拉缺、补缺、全量 FontLoader 重载）。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_sync);
  }

  /// 桌面端导入：复制进缓存目录（重名加后缀），随后 refresh 推桶。
  Future<void> importFont(String sourcePath) async {
    final dir = Directory(await _cacheDir());
    await dir.create(recursive: true);
    final ext = p.extension(sourcePath).toLowerCase();
    final stem = p.basenameWithoutExtension(sourcePath);
    var name = '$stem$ext';
    var target = File(p.join(dir.path, name));
    for (var n = 2; await target.exists(); n++) {
      name = '${stem}_$n$ext';
      target = File(p.join(dir.path, name));
    }
    await File(sourcePath).copy(target.path);
    await refresh();
  }

  Future<String> _cacheDir() async {
    final root = await resolveLocalRoot(ref.read(settingsRepositoryProvider));
    return p.join(root, '_font_cache');
  }

  Future<List<FontEntry>> _sync() async {
    final dir = Directory(await _cacheDir());
    await dir.create(recursive: true);
    final client = ref.read(bucketClientProvider);
    if (client != null) {
      try {
        // 拉：桶里有的本地缺 → 下载落盘
        final keys = await client.listKeys(LibraryPaths.fontsPrefix, max: 200);
        for (final k in keys) {
          final name = p.basename(k);
          if (!_fontExts.contains(p.extension(name).toLowerCase())) continue;
          final local = File(p.join(dir.path, name));
          if (await local.exists()) continue;
          final bytes = await withRetry<Uint8List>(() => client.getAll(k));
          await local.writeAsBytes(bytes, flush: true);
        }
        // 推：本地有桶无 → 上传（幂等；不做删除方向，防误删桶内字体）
        final remoteNames = keys.map(p.basename).toSet();
        await for (final f in dir.list()) {
          if (f is! File) continue;
          final name = p.basename(f.path);
          if (!_fontExts.contains(p.extension(name).toLowerCase())) continue;
          if (remoteNames.contains(name)) continue;
          await withRetry<void>(
            () async =>
                client.put(LibraryPaths.fontFile(name), await f.readAsBytes()),
          );
        }
      } on Object {
        // 桶不可用（离线/未配置）退回本地已有字体，阅读不受影响
      }
    }
    // 全量加载（字体可能更新过，重载幂等；单个坏文件不拖垮整个库）
    final entries = <FontEntry>[];
    final files = await dir
        .list()
        .where(
          (e) =>
              e is File &&
              _fontExts.contains(p.extension(e.path).toLowerCase()),
        )
        .map((e) => e.path)
        .toList();
    files.sort();
    for (final path in files) {
      final name = p.basename(path);
      final family = fontFamilyFor(name);
      try {
        final loader = FontLoader(family)
          ..addFont(
            File(path).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await loader.load();
        entries.add(FontEntry(fileName: name, family: family, path: path));
      } on Object {
        // 加载失败的（截断文件等）跳过，下次同步重试
      }
    }
    return entries;
  }
}

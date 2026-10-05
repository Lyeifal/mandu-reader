/// 小说下载端到端编排（零 Flutter 依赖；drift/任务层经回调接入）。
///
/// 流程（对应设计文档 §8.2/§8.3）：staging 逐章抓取（tmp 幂等补章）→
/// 清洗 → 缺章则报 [NovelDownloadIncomplete]（tmp 保留，重试整任务重入）→
/// 拼合 book.txt/chapters.json/meta.json → 封面 → 落正式目录。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/retry.dart';
import 'source_assembly.dart';
import 'source_chapter.dart';
import 'source_cleaner.dart';
import 'source_http.dart';
import 'source_models.dart';
import 'source_selector.dart';

/// 作品 id：`src_<sourceId>_<bookUrl md5[:12]>`（同书重传/重试恒定同 id）。
String novelWorkId(String sourceId, String bookUrl) =>
    'src_${sourceId}_${md5.convert(utf8.encode(bookUrl)).toString().substring(0, 12)}';

/// 启动配置快照（任务持久化 + 续跑输入；全 JSON 可序列化）。
class NovelSnapshot {
  const NovelSnapshot({
    required this.sourceId,
    required this.bookUrl,
    required this.bookName,
    required this.author,
    required this.status,
    this.coverUrl = '',
    this.proxy = '',
    this.chapters = const [],
  });

  final String sourceId;

  /// 详情页 URL（workId 的种子；追更回溯用）。
  final String bookUrl;
  final String bookName;
  final String author;
  final String status;
  final String coverUrl;
  final String proxy;
  final List<SourceChapter> chapters;

  String get workId => novelWorkId(sourceId, bookUrl);

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'bookUrl': bookUrl,
    'bookName': bookName,
    'author': author,
    'status': status,
    'coverUrl': coverUrl,
    'proxy': proxy,
    'chapters': [
      for (final c in chapters)
        {'title': c.title, 'url': c.url, 'order': c.order},
    ],
  };

  factory NovelSnapshot.fromJson(Map<String, dynamic> j) => NovelSnapshot(
    sourceId: (j['sourceId'] ?? '').toString(),
    bookUrl: (j['bookUrl'] ?? '').toString(),
    bookName: (j['bookName'] ?? '').toString(),
    author: (j['author'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    coverUrl: (j['coverUrl'] ?? '').toString(),
    proxy: (j['proxy'] ?? '').toString(),
    chapters: [
      for (final c in (j['chapters'] as List? ?? const []))
        SourceChapter(
          title: (c['title'] ?? '').toString(),
          url: (c['url'] ?? '').toString(),
          order: (c['order'] as num?)?.toInt() ?? 0,
        ),
    ],
  );
}

/// 有缺章：任务层据此标 failed（error 带章号清单），tmp 保留待补。
class NovelDownloadIncomplete implements Exception {
  NovelDownloadIncomplete(this.failedChapters);

  final List<int> failedChapters;

  @override
  String toString() =>
      '缺 ${failedChapters.length} 章: ${failedChapters.join(',')}';
}

class NovelPipelineResult {
  const NovelPipelineResult({
    required this.totalChapters,
    required this.failedChapters,
    required this.workDir,
  });

  final int totalChapters;
  final List<int> failedChapters;
  final String workDir;

  bool get complete => failedChapters.isEmpty;
}

/// 有界并发收集：N 个 worker 抢 index，保序；单元素失败记 null 不炸整体。
/// （jm_downloader._mapLimited 的失败容忍版）
Future<List<R?>> mapLimitedCollect<R>(
  int length,
  int limit,
  Future<R> Function(int index) fn,
) async {
  final out = List<R?>.filled(length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= length) return;
      try {
        out[i] = await fn(i);
      } on Object {
        out[i] = null; // 失败占位
      }
    }
  }

  await Future.wait(List.generate(limit.clamp(1, 64), (_) => worker()));
  return out;
}

class SourcePipeline {
  SourcePipeline({
    required this.rule,
    required this.http,
    SelectorEngine? engine,
  }) : engine = engine ?? SelectorEngine();

  final SourceRule rule;
  final SourceHttp http;
  final SelectorEngine engine;

  /// 抓一章：单次尝试的抓取 + 清洗。重试由调用方按章编排。
  Future<ChapterDraft> fetchChapter(
    SourceChapter ch, {
    void Function(Object error, int attempt)? onRetry,
    int attempts = 3,
  }) async {
    final fetcher = SourceChapterFetcher(rule, http, engine);
    final raw = await withRetry<String>(
      () => fetcher.fetch(ch.url),
      attempts: attempts,
      onRetry: onRetry,
    );
    final cleaned = cleanChapter(rule.chapter, ch.title, raw);
    // staging 行格式是「标题\n段落…\n」：标题带换行会破坏续跑时的解析，先行收敛
    final title = cleaned.title.replaceAll('\n', ' ').trim();
    return ChapterDraft(title, cleaned.paragraphs);
  }

  /// 端到端下载到 `<root>/<workId>/`。
  Future<NovelPipelineResult> download({
    required String root,
    required NovelSnapshot snap,
    required int concurrency,
    required int attempts,
    required void Function(String phase) onProgress,
    void Function(int done, int total)? onCount,
  }) async {
    final dir = Directory(p.join(root, snap.workId));
    final tmp = Directory(p.join(root, '_novel_tmp', snap.workId));
    await tmp.create(recursive: true);
    await dir.create(recursive: true);

    // 1) staging 逐章（已存在的 tmp 文件跳过 → 重试 = 幂等补章）
    final total = snap.chapters.length;
    final drafts = await mapLimitedCollect<ChapterDraft>(total, concurrency, (
      i,
    ) async {
      final ch = snap.chapters[i];
      final file = File(p.join(tmp.path, '$i.txt'));
      if (await file.exists()) {
        final cached = await file.readAsString();
        final lines = const LineSplitter().convert(cached);
        // staging 行格式：标题 + 段落（首行是标题）
        final title = lines.isNotEmpty ? lines.first : ch.title;
        return ChapterDraft(
          title,
          lines.skip(1).where((l) => l.isNotEmpty).toList(),
        );
      }
      onProgress('下载第 ${i + 1}/$total 章《${ch.title}》');
      final draft = await fetchChapter(
        ch,
        attempts: attempts,
        onRetry: (e, a) => onProgress('第 ${i + 1} 章重试 $a：$e'),
      );
      await file.writeAsString(
        '${draft.title}\n${draft.paragraphs.join('\n')}',
        flush: true,
      );
      onCount?.call(i + 1, total);
      return draft;
    });

    // 2) 缺章检查
    final failed = <int>[
      for (var i = 0; i < total; i++)
        if (drafts[i] == null) i + 1,
    ];
    if (failed.isNotEmpty) {
      throw NovelDownloadIncomplete(failed);
    }

    // 3) 拼合落盘
    onProgress('拼合成书…');
    final today = _today();
    final book = assembleBook(
      workId: snap.workId,
      chapters: drafts.cast<ChapterDraft>(),
      bookName: snap.bookName,
      author: snap.author.isEmpty ? '佚名' : snap.author,
      status: snap.status.contains('完') ? 'completed' : 'ongoing',
      sourceId: snap.sourceId,
      bookUrl: snap.bookUrl,
      today: today,
    );
    await File(p.join(dir.path, 'book.txt'))
        .writeAsString(book.bookTxt, flush: true);
    await File(p.join(dir.path, 'chapters.json'))
        .writeAsString(book.chaptersJson, flush: true);
    await File(p.join(dir.path, 'meta.json'))
        .writeAsString(book.metaJson, flush: true);

    // 4) 封面（失败仅告警，不挡下载）
    if (snap.coverUrl.isNotEmpty) {
      try {
        onProgress('下载封面…');
        final bytes = await http.getBytes(snap.coverUrl);
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          await File(p.join(dir.path, 'cover.jpg'))
              .writeAsBytes(img.encodeJpg(decoded, quality: 88), flush: true);
        }
      } on Object {
        // 无封面也能读
      }
    }

    // 5) 清理 staging
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on Object {
      // tmp 清不掉不碍事
    }
    onProgress('完成');
    return NovelPipelineResult(
      totalChapters: total,
      failedChapters: const [],
      workDir: dir.path,
    );
  }
}

String _today() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

/// 书源 glue 层：assets 内置源 + DB 覆盖层合并、HTTP 客户端工厂、
/// 单源测试（书源巡检核心，App 内按钮与 tool/source_doctor 共用）。
library;

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'source_http.dart';
import 'source_loader.dart';
import 'source_models.dart';
import 'source_ops.dart';
import 'source_probe.dart';

/// 内置书源（assets/rules/sources.json）。
final builtinSourcesProvider = FutureProvider<List<SourceRule>>((ref) async {
  final content = await rootBundle.loadString('assets/rules/sources.json');
  return parseRulesJson(content);
});

/// DB 覆盖层（NovelSources 表行）。
final sourceOverridesProvider = StreamProvider<List<SourceOverride>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(
    db.novelSources,
  )..orderBy([(t) => OrderingTerm.asc(t.sourceId)])).watch().map(
    (rows) => [
      for (final r in rows)
        SourceOverride(
          sourceId: r.sourceId,
          json: r.json,
          enabled: r.enabled,
          disableReason: r.disableReason,
        ),
    ],
  );
});

/// 合并后的全部源（内置 ∪ DB）。
final allSourcesProvider = Provider<AsyncValue<List<SourceRule>>>((ref) {
  final builtin = ref.watch(builtinSourcesProvider);
  final overrides = ref.watch(sourceOverridesProvider).value ?? const [];
  return builtin.whenData((rules) => mergeOverrides(rules, overrides));
});

/// 可用源：未禁用且通过校验（搜索另要求 searchable）。
final enabledSourcesProvider = Provider<List<SourceRule>>((ref) {
  final all = ref.watch(allSourcesProvider).value ?? const [];
  final ops = buildDefaultOps();
  final out = <SourceRule>[];
  for (final r in all) {
    if (r.disabled) continue;
    if (r.siteUrl.isEmpty || validateRule(r, ops).isNotEmpty) continue;
    out.add(r);
  }
  return out;
});

/// 单源最近测试结果（源管理页展示用；NovelSources 表行）。
final sourceTestResultsProvider =
    StreamProvider<Map<String, ({String result, DateTime? testedAt})>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return db
          .select(db.novelSources)
          .watch()
          .map(
            (rows) => {
              for (final r in rows)
                if (r.lastTestResult.isNotEmpty)
                  r.sourceId: (
                    result: r.lastTestResult,
                    testedAt: r.lastTestedAt,
                  ),
            },
          );
    });

/// 按 sourceId 查源（含禁用态，任务续跑用）。
SourceRule? findSource(List<SourceRule> rules, String sourceId) {
  for (final r in rules) {
    if (r.sourceId == sourceId) return r;
  }
  return null;
}

/// 书源抓取配置（规则 crawl 段覆盖全局设置）。
class SourceCrawlConfig {
  const SourceCrawlConfig({
    required this.concurrency,
    required this.attempts,
    required this.minIntervalMs,
    required this.maxIntervalMs,
  });

  final int concurrency;
  final int attempts;
  final int minIntervalMs;
  final int maxIntervalMs;
}

/// 读 provider 的最小抽象（Ref / ProviderContainer 的 read 都匹配）。
typedef ReadFn = T Function<T>(Provider<T> provider);

/// 解析单源生效配置（全局设置在 SettingsRepository，crawl 段优先）。
Future<SourceCrawlConfig> resolveCrawlConfig(
  ReadFn read,
  SourceRule rule,
) async {
  final repo = read(settingsRepositoryProvider);
  Future<int> gi(String key, int def) async =>
      int.tryParse(await repo.get(key) ?? '') ?? def;
  final g = SourceCrawlConfig(
    concurrency: (await gi('source.concurrency', 3)).clamp(1, 4),
    attempts: (await gi('source.chapter_retry', 3)).clamp(1, 5),
    minIntervalMs: (await gi('source.min_interval_ms', 300)).clamp(0, 10000),
    maxIntervalMs: (await gi('source.max_interval_ms', 800)).clamp(0, 30000),
  );
  final c = rule.crawl;
  return SourceCrawlConfig(
    concurrency: (c.concurrency ?? g.concurrency).clamp(1, 4),
    attempts: (c.maxAttempts ?? g.attempts).clamp(1, 5),
    minIntervalMs: c.minIntervalSec != null
        ? c.minIntervalSec! * 1000
        : g.minIntervalMs,
    maxIntervalMs: c.maxIntervalSec != null
        ? c.maxIntervalSec! * 1000
        : g.maxIntervalMs,
  );
}

/// 书源 HTTP 客户端（代理：needProxy 源或 proxy_all 强制）。
/// 限流间隔在此解析：规则 crawl 段（秒）覆盖全局设置（毫秒）。
Future<SourceHttp> buildSourceHttp(ReadFn read, SourceRule rule) async {
  final repo = read(settingsRepositoryProvider);
  final global = (await repo.get('source.proxy'))?.trim() ?? '';
  final all = (await repo.get('source.proxy_all')) == 'true';
  final proxy = (rule.needProxy || all) ? global : '';
  Future<int> gi(String key, int def) async =>
      int.tryParse(await repo.get(key) ?? '') ?? def;
  final gMin = await gi('source.min_interval_ms', 300);
  final gMax = await gi('source.max_interval_ms', 800);
  final c = rule.crawl;
  return SourceHttpClient(
    proxy: proxy,
    minIntervalMs: c.minIntervalSec != null ? c.minIntervalSec! * 1000 : gMin,
    maxIntervalMs: c.maxIntervalSec != null ? c.maxIntervalSec! * 1000 : gMax,
  );
}

/// 单源四步巡检：搜索 → 详情 → 目录 → 正文（实现在 source_probe.dart，
/// 纯引擎层；这里只负责按设置构建 http）。
/// 返回 `ok` 或 `fail@step: 原因`；CF 挑战返回 `cf_challenge@…`。
Future<String> testSource(
  ReadFn read,
  SourceRule rule, {
  String? probeKeyword,
  String? probeBookUrl,
}) async {
  final http = await buildSourceHttp(read, rule);
  return probeSource(
    rule,
    http,
    probeKeyword: probeKeyword,
    probeBookUrl: probeBookUrl,
  );
}

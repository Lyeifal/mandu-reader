import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/db/app_database.dart';
import '../downloader/jm_pipeline.dart';
import '../providers.dart';

/// 标签组合逻辑：与（全含）/ 或（任一）/ 非（全不含）。
enum TagMode { and, or, not }

/// 时间筛选作用字段：发布时间 | 完结时间。
enum TimeField { published, completed }

enum ShelfSort { syncedAt, lastUpdated, title }

/// 书架筛选条件（不可变；整体作为 provider 键）。
class ShelfFilter {
  const ShelfFilter({
    this.type = 'novel',
    this.novelCat = '',
    this.author = '',
    this.status = '',
    this.tagModes = const {},
    this.storage = '',
    this.query = '',
    this.sort = ShelfSort.syncedAt,
    this.hasZh = '',
    this.zhQuality = '',
    this.timeField = TimeField.published,
    this.timeFrom = '',
    this.timeTo = '',
  });

  /// '' | novel | manga（顶部页签；解锁默认进小说）
  final String type;

  /// 小说分类：'' 全部 | classic 传统小说 | web 网文（按标签匹配）。
  final String novelCat;

  /// '' = 不限；否则精确匹配作者（可从详情页点选）。
  final String author;
  final String status;

  /// 每个已选标签各自的逻辑（或/非/与）；键即选中的标签。
  final Map<String, TagMode> tagModes;

  /// 存储范围：'' 不限 | local 本地 | cloud 云端。
  final String storage;
  final String query;
  final ShelfSort sort;

  /// '' | yes | no
  final String hasZh;

  /// '' | high | medium | low
  final String zhQuality;

  final TimeField timeField;

  /// YYYY-MM；空 = 该端不约束。
  final String timeFrom;
  final String timeTo;

  static const empty = ShelfFilter();

  bool get isDefault =>
      type.isEmpty &&
      author.isEmpty &&
      status.isEmpty &&
      tagModes.isEmpty &&
      storage.isEmpty &&
      query.trim().isEmpty &&
      hasZh.isEmpty &&
      zhQuality.isEmpty &&
      timeFrom.isEmpty &&
      timeTo.isEmpty;

  bool get hasTimeRange => timeFrom.isNotEmpty || timeTo.isNotEmpty;

  ShelfFilter copyWith({
    String? type,
    String? novelCat,
    String? author,
    String? status,
    Map<String, TagMode>? tagModes,
    String? storage,
    String? query,
    ShelfSort? sort,
    String? hasZh,
    String? zhQuality,
    TimeField? timeField,
    String? timeFrom,
    String? timeTo,
  }) => ShelfFilter(
    type: type ?? this.type,
    novelCat: novelCat ?? this.novelCat,
    author: author ?? this.author,
    status: status ?? this.status,
    tagModes: tagModes ?? this.tagModes,
    storage: storage ?? this.storage,
    query: query ?? this.query,
    sort: sort ?? this.sort,
    hasZh: hasZh ?? this.hasZh,
    zhQuality: zhQuality ?? this.zhQuality,
    timeField: timeField ?? this.timeField,
    timeFrom: timeFrom ?? this.timeFrom,
    timeTo: timeTo ?? this.timeTo,
  );

  @override
  bool operator ==(Object other) =>
      other is ShelfFilter &&
      other.type == type &&
      other.novelCat == novelCat &&
      other.author == author &&
      other.status == status &&
      mapEquals(other.tagModes, tagModes) &&
      other.storage == storage &&
      other.query == query &&
      other.sort == sort &&
      other.hasZh == hasZh &&
      other.zhQuality == zhQuality &&
      other.timeField == timeField &&
      other.timeFrom == timeFrom &&
      other.timeTo == timeTo;

  @override
  int get hashCode => Object.hash(
    type,
    novelCat,
    author,
    status,
    Object.hashAll(tagModes.entries.map((e) => Object.hash(e.key, e.value))),
    storage,
    query,
    sort,
    hasZh,
    zhQuality,
    timeField,
    timeFrom,
    timeTo,
  );
}

class _ShelfFilterNotifier extends Notifier<ShelfFilter> {
  @override
  ShelfFilter build() => ShelfFilter.empty;

  void apply(ShelfFilter value) => state = value;
}

class _ShelfPageNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void go(int page) => state = page;
}

class _ShelfPageSizeNotifier extends Notifier<int> {
  @override
  int build() => 48;

  void set(int size) => state = size;
}

final shelfFilterProvider = NotifierProvider<_ShelfFilterNotifier, ShelfFilter>(
  _ShelfFilterNotifier.new,
);
final shelfPageProvider = NotifierProvider<_ShelfPageNotifier, int>(
  _ShelfPageNotifier.new,
);
final shelfPageSizeProvider = NotifierProvider<_ShelfPageSizeNotifier, int>(
  _ShelfPageSizeNotifier.new,
);

/// 组合查询键：筛选 + 页码 + 每页条数。
final shelfQueryProvider = Provider<(ShelfFilter, int, int)>(
  (ref) => (
    ref.watch(shelfFilterProvider),
    ref.watch(shelfPageProvider),
    ref.watch(shelfPageSizeProvider),
  ),
);

Expression<bool>? _where($WorksTable t, ShelfFilter f) {
  final conds = <Expression<bool>>[];
  if (f.type.isNotEmpty) conds.add(t.type.equals(f.type));
  if (f.type == 'novel' && f.novelCat.isNotEmpty) {
    // 小说分类按标签匹配（起点/番茄风格分类，给作品打上对应标签即归入）
    conds.add(t.tags.like('%${f.novelCat}%'));
  }
  if (f.author.isNotEmpty) conds.add(t.author.equals(f.author));
  if (f.status.isNotEmpty) conds.add(t.status.equals(f.status));
  if (f.storage == 'local') {
    conds.add(t.localOnly.equals(true));
  } else if (f.storage == 'cloud') {
    conds.add(t.localOnly.equals(false));
  }
  if (f.hasZh == 'yes') {
    conds.add(t.hasZh.equals(true));
  } else if (f.hasZh == 'no') {
    conds.add(t.hasZh.equals(false));
  }
  if (f.zhQuality.isNotEmpty) conds.add(t.zhQuality.equals(f.zhQuality));
  if (f.hasTimeRange) {
    final col = switch (f.timeField) {
      TimeField.published => t.publishedAt,
      TimeField.completed => t.completedAt,
    };
    if (f.timeFrom.isNotEmpty) {
      conds.add(col.isBiggerOrEqualValue(f.timeFrom));
    }
    if (f.timeTo.isNotEmpty) {
      conds.add(col.isSmallerOrEqualValue(f.timeTo));
    }
  }
  // tags 列是 JSON 文本，用包含匹配近似；FTS5 上线（M7）后替换。
  // 每个标签独立逻辑：与=AND，或=同组 OR，非=NOT。
  if (f.tagModes.isNotEmpty) {
    final ors = <Expression<bool>>[];
    for (final e in f.tagModes.entries) {
      final like = t.tags.like('%${e.key}%');
      switch (e.value) {
        case TagMode.and:
          conds.add(like);
        case TagMode.or:
          ors.add(like);
        case TagMode.not:
          conds.add(like.not());
      }
    }
    if (ors.isNotEmpty) {
      var e = ors.first;
      for (final c in ors.skip(1)) {
        e = e | c;
      }
      conds.add(e);
    }
  }
  final q = f.query.trim();
  if (q.isNotEmpty) {
    final like = '%$q%';
    conds.add(
      t.title.like(like) |
          t.titleJp.like(like) |
          t.author.like(like) |
          t.series.like(like),
    );
  }
  if (conds.isEmpty) return null;
  var e = conds.first;
  for (final c in conds.skip(1)) {
    e = e & c;
  }
  return e;
}

List<OrderClauseGenerator<$WorksTable>> _orderBy(ShelfSort sort) =>
    switch (sort) {
      ShelfSort.syncedAt => [(t) => OrderingTerm.desc(t.syncedAt)],
      ShelfSort.lastUpdated => [(t) => OrderingTerm.desc(t.lastUpdated)],
      ShelfSort.title => [(t) => OrderingTerm.asc(t.title)],
    };

Future<List<Work>> _runQuery(
  AppDatabase db,
  (ShelfFilter, int, int) key,
) async {
  final (filter, page, pageSize) = key;
  final w = _where(db.works, filter);
  final q = db.select(db.works)
    ..orderBy(_orderBy(filter.sort))
    ..limit(pageSize, offset: (page - 1) * pageSize);
  if (w != null) q.where((t) => w);
  return q.get();
}

/// 查询结果缓存：同一筛选条件翻过的页留在内存里，来回翻页/切筛选即时出结果；
/// 同步完成后由调用方 clear（数据可能已变）。
final shelfWorksCacheProvider =
    Provider<Map<(ShelfFilter, int, int), List<Work>>>((ref) => {});

class _ShelfWorksNotifier extends AsyncNotifier<List<Work>> {
  (ShelfFilter, int, int)? _current;

  @override
  Future<List<Work>> build() async {
    final key = ref.watch(shelfQueryProvider);
    _current = key;
    final cache = ref.watch(shelfWorksCacheProvider);
    final hit = cache[key];
    if (hit != null) {
      // 缓存命中：先出旧数据，后台静默刷新
      Future(() async {
        final fresh = await _runQuery(ref.read(appDatabaseProvider), key);
        cache[key] = fresh;
        if (key == _current && ref.mounted) state = AsyncData(fresh);
      });
      return hit;
    }
    final list = await _runQuery(ref.read(appDatabaseProvider), key);
    cache[key] = list;
    return list;
  }
}

/// 当前页的网格数据（带缓存）。
final shelfWorksProvider =
    AsyncNotifierProvider<_ShelfWorksNotifier, List<Work>>(
      _ShelfWorksNotifier.new,
    );

/// 命中总数（翻页器用）。
final shelfTotalProvider = FutureProvider<int>((ref) async {
  final filter = ref.watch(shelfFilterProvider);
  final db = ref.watch(appDatabaseProvider);
  final w = _where(db.works, filter);
  final q = db.selectOnly(db.works)..addColumns([db.works.id.count()]);
  if (w != null) q.where(w);
  final row = await q.getSingle();
  return row.read(db.works.id.count()) ?? 0;
});

/// 本地缓存根（设置可配）。
final localRootProvider = FutureProvider<String>(
  (ref) => resolveLocalRoot(ref.watch(settingsRepositoryProvider)),
);

/// 封面可显示路径：本地作品读本地文件，桶内作品下载到缓存；
/// AVIF 自动转 JPEG。拿不到返回 null。
/// 封面来源：(路径/URL, 是否远端)。AVIF 由显示层按扩展名分派解码器。
final coverSourceProvider = FutureProvider.family<(String, bool)?, Work>((
  ref,
  work,
) async {
  final cover = work.cover;
  if (cover == null || cover.isEmpty) return null;
  if (work.localOnly) {
    final root = await ref.watch(localRootProvider.future);
    var f = File(p.join(root, work.id, cover));
    if (!await f.exists()) {
      // 封面字段可能因压缩换名（webp→avif）而过期：回退目录里第一页图
      final dir = Directory(p.join(root, work.id));
      if (await dir.exists()) {
        const exts = {
          '.jpg',
          '.jpeg',
          '.png',
          '.webp',
          '.avif',
          '.gif',
          '.bmp',
        };
        final files = await dir
            .list()
            .where(
              (e) =>
                  e is File && exts.contains(p.extension(e.path).toLowerCase()),
            )
            .map((e) => e.path)
            .toList();
        files.sort();
        if (files.isNotEmpty) f = File(files.first);
      }
    }
    if (!await f.exists()) return null;
    return (f.path, false);
  }
  final client = ref.read(bucketClientProvider);
  if (client == null) return null;
  try {
    return (await client.presignGet(cover), true);
  } on Object {
    return null;
  }
});

/// 标签 MRU 排序（纯函数）：最近点过的在前，其余按计数降序。
List<({String tag, int count})> orderTagsByRecency(
  List<({String tag, int count})> tags,
  List<String> recent,
) {
  final byTag = {for (final t in tags) t.tag: t};
  final out = <({String tag, int count})>[];
  final seen = <String>{};
  for (final r in recent) {
    final t = byTag[r];
    if (t != null && seen.add(r)) out.add(t);
  }
  final rest = tags.where((t) => !seen.contains(t.tag)).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  out.addAll(rest);
  return out;
}

/// 最近点选的标签（MRU，最多留 20 个），持久化在设置里。
final recentTagsProvider = FutureProvider<List<String>>((ref) async {
  final raw = await ref
      .watch(settingsRepositoryProvider)
      .get('shelf.recent_tags');
  if (raw == null || raw.isEmpty) return const [];
  try {
    return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
  } on Object {
    return const [];
  }
});

/// 把标签提到 MRU 队首并落盘。
Future<void> pushRecentTag(WidgetRef ref, String tag) async {
  final repo = ref.read(settingsRepositoryProvider);
  final raw = await repo.get('shelf.recent_tags');
  List<String> list = const [];
  if (raw != null && raw.isNotEmpty) {
    try {
      list = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } on Object {
      list = const [];
    }
  }
  list = [tag, ...list.where((e) => e != tag)].take(20).toList();
  await repo.set('shelf.recent_tags', jsonEncode(list));
  ref.invalidate(recentTagsProvider);
}

/// 最近搜索词（MRU，最多 20 条）；参与历史标签排序。
final recentQueriesProvider = FutureProvider<List<String>>((ref) async {
  final raw = await ref
      .watch(settingsRepositoryProvider)
      .get('shelf.recent_queries');
  if (raw == null || raw.isEmpty) return const [];
  try {
    return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
  } on Object {
    return const [];
  }
});

Future<void> pushRecentQuery(WidgetRef ref, String query) async {
  final q = query.trim();
  if (q.isEmpty) return;
  final repo = ref.read(settingsRepositoryProvider);
  final raw = await repo.get('shelf.recent_queries');
  List<String> list = const [];
  if (raw != null && raw.isNotEmpty) {
    try {
      list = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } on Object {
      list = const [];
    }
  }
  list = [q, ...list.where((e) => e != q)].take(20).toList();
  await repo.set('shelf.recent_queries', jsonEncode(list));
  ref.invalidate(recentQueriesProvider);
}

/// 标签活跃位次（越小越近）：点选 > 搜索词包含；无活跃返回大数（纯函数）。
int tagActivityRank(
  String tag,
  List<String> recentTags,
  List<String> recentQueries,
) {
  const inf = 1 << 30;
  final ti = recentTags.indexOf(tag);
  final qi = recentQueries.indexWhere((q) => q.contains(tag));
  final t = ti < 0 ? inf : ti;
  final q = qi < 0 ? inf : qi + 1000;
  return t < q ? t : q;
}

/// 全库标签计数（筛选面板用）。按类型隔离：传 '' 表示全部。
final shelfTagsProvider =
    FutureProvider.family<List<({String tag, int count})>, String>((
      ref,
      type,
    ) async {
      final db = ref.watch(appDatabaseProvider);
      final sel = db.select(db.works);
      if (type.isNotEmpty) sel.where((t) => t.type.equals(type));
      final rows = await sel.get();
      final counts = <String, int>{};
      for (final r in rows) {
        try {
          for (final e in jsonDecode(r.tags) as List) {
            final s = e.toString();
            if (s.isNotEmpty) counts[s] = (counts[s] ?? 0) + 1;
          }
        } on Object {
          // 坏 JSON 行跳过，不影响面板
        }
      }
      final list =
          counts.entries.map((e) => (tag: e.key, count: e.value)).toList()
            ..sort((a, b) => b.count.compareTo(a.count));
      return list;
    });

/// 全库状态计数（筛选面板用）。
final shelfStatusesProvider =
    FutureProvider<List<({String status, int count})>>((ref) async {
      final db = ref.watch(appDatabaseProvider);
      final q = db.selectOnly(db.works)
        ..addColumns([db.works.status, db.works.id.count()])
        ..groupBy([db.works.status]);
      final rows = await q.get();
      final list = <({String status, int count})>[];
      for (final r in rows) {
        final s = r.read(db.works.status) ?? '';
        list.add((status: s, count: r.read(db.works.id.count()) ?? 0));
      }
      list.sort((a, b) => b.count.compareTo(a.count));
      return list;
    });

/// 全库作者计数（筛选面板下拉用）。
final shelfAuthorsProvider = FutureProvider<List<({String author, int count})>>(
  (ref) async {
    final db = ref.watch(appDatabaseProvider);
    final q = db.selectOnly(db.works)
      ..addColumns([db.works.author, db.works.id.count()])
      ..where(db.works.author.length.isBiggerThanValue(0))
      ..groupBy([db.works.author]);
    final rows = await q.get();
    final list = <({String author, int count})>[];
    for (final r in rows) {
      final a = r.read(db.works.author) ?? '';
      list.add((author: a, count: r.read(db.works.id.count()) ?? 0));
    }
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  },
);

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/exceptions.dart';
import '../../core/retry.dart';
import '../../data/db/app_database.dart';
import '../bucket/bucket_client.dart';
import '../bucket/path_helper.dart';
import '../providers.dart';
import '../settings/settings_repository.dart';
import 'works_index.dart' show BadLine;

final _log = Logger('EventsLog');

/// events.jsonl 超过该体积时，同步流程顺手折叠（见 [compactEvents]）。
const kEventsCompactThreshold = 256 * 1024;

/// 用户状态事件（设计文档 §5：追加式日志、重放合并、确定性）。
///
/// 当前类型：novel_progress / manga_progress / bookmark / bookmark_delete，
/// 解析器同时接受 snapshot 行（30 天折叠产物，视同 progress 参与 LWW）。
class ReaderEvent {
  const ReaderEvent({
    required this.ts,
    required this.dev,
    required this.type,
    this.work,
    this.id,
    this.loc,
    this.note,
    this.color,
    this.schemaVersion = 1,
  });

  /// 事件时间；解析失败回退 epoch（自然输掉 LWW）。
  final DateTime ts;
  final String dev;
  final String type;
  final String? work;
  final String? id;
  final Map<String, dynamic>? loc;
  final String? note;
  final String? color;
  final int schemaVersion;

  bool get isProgress =>
      type == 'novel_progress' ||
      type == 'manga_progress' ||
      type == 'snapshot';

  factory ReaderEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    if (type.isEmpty) throw const FormatException('缺少 type');
    return ReaderEvent(
      ts:
          DateTime.tryParse((json['ts'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      dev: (json['dev'] ?? '').toString(),
      type: type,
      work: json['work']?.toString(),
      id: json['id']?.toString(),
      loc: json['loc'] is Map<String, dynamic>
          ? json['loc'] as Map<String, dynamic>
          : null,
      note: json['note']?.toString(),
      color: json['color']?.toString(),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'ts': ts.toIso8601String(),
    'dev': dev,
    'type': type,
    if (work != null) 'work': work,
    if (id != null) 'id': id,
    if (loc != null) 'loc': loc,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (color != null && color!.isNotEmpty) 'color': color,
  };
}

/// 事件构造辅助（本地产生事件用）。
Map<String, dynamic> progressEvent({
  required String dev,
  required String type,
  required String work,
  required Map<String, dynamic> loc,
}) => {
  'schema_version': 1,
  'ts': DateTime.now().toIso8601String(),
  'dev': dev,
  'type': type,
  'work': work,
  'loc': loc,
};

Map<String, dynamic> bookmarkEvent({
  required String dev,
  required String id,
  required String work,
  required Map<String, dynamic> loc,
  String note = '',
  String color = 'red',
}) => {
  'schema_version': 1,
  'ts': DateTime.now().toIso8601String(),
  'dev': dev,
  'type': 'bookmark',
  'id': id,
  'work': work,
  'loc': loc,
  if (note.isNotEmpty) 'note': note,
  'color': color,
};

Map<String, dynamic> bookmarkDeleteEvent({
  required String dev,
  required String id,
}) => {
  'schema_version': 1,
  'ts': DateTime.now().toIso8601String(),
  'dev': dev,
  'type': 'bookmark_delete',
  'id': id,
};

/// 本机设备标识（合并决胜键 §5.1）；首次生成后落设置。
Future<String> resolveDeviceName(SettingsRepository repo) async {
  final existing = (await repo.get('device.name'))?.trim() ?? '';
  if (existing.isNotEmpty) return existing;
  final name =
      'dev_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
      '${Random().nextInt(1 << 32).toRadixString(36)}';
  await repo.set('device.name', name);
  return name;
}

/// 逐行解析 events.jsonl：空行跳过，坏行收集（§5.2），不抛异常。
(List<ReaderEvent>, List<BadLine>) parseEventsLog(String content) {
  final events = <ReaderEvent>[];
  final bad = <BadLine>[];
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) continue;
    try {
      events.add(ReaderEvent.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } on Object catch (e) {
      bad.add(BadLine(i + 1, raw, e.toString()));
    }
  }
  return (events, bad);
}

/// 重放结果：progress 按 work 已决胜（LWW），bookmarks 按 id 已
/// 剔除被删除项；deletedBookmarkIds 供落库时清理本地。
class ReplayResult {
  ReplayResult(this.progress, this.bookmarks, this.deletedBookmarkIds);

  final Map<String, ReaderEvent> progress; // key = work
  final Map<String, ReaderEvent> bookmarks; // key = id
  final Set<String> deletedBookmarkIds;
}

/// 折叠结果统计（日志/测试用）。
class EventCompaction {
  const EventCompaction({
    required this.content,
    required this.progressKept,
    required this.bookmarksKept,
    required this.badDropped,
  });

  /// 折叠后的文件内容（确定性：排序输出，同输入必同输出）。
  final String content;
  final int progressKept;
  final int bookmarksKept;

  /// 坏行/无效行直接丢弃数——它们本就只被跳过。
  final int badDropped;
}

/// 事件日志折叠（设计文档 §5.1「30 天折叠」的推广版：不限时间，留赢家）：
/// 把追加日志压成「必胜者名单」，文件大小从 O(事件数) 降为 O(作品数+书签数)。
///
/// - 进度类：每个 work 只留决胜者，改写为 snapshot 行（保留原始 ts/loc，
///   folded_from 记录折叠掉的条数）；重放端本就按 progress 处理 snapshot
/// - 书签：每个 id 只留最新状态事件（创建或删除 whichever 新）——
///   删除行必须留下压住可能复活自旧设备的创建行
/// - 坏行直接丢弃
///
/// 竞态安全：压缩只是「留赢家的有损重写」。两台设备同时折叠/追加时，
/// 最坏结果是输家行被复活一瞬，但 ts 都赢不过留下的赢家，重放结果不变。
EventCompaction compactEvents(String content) {
  final progress = <String, ReaderEvent>{};
  final progressFolded = <String, int>{};
  final bookmarkStates = <String, ReaderEvent>{};
  // 未来 schema 的未知类型事件：不解析、原样保留（保守不丢语义）
  final unknownRaw = <String>[];
  var bad = 0;
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(line) as Map<String, dynamic>;
    } on Object {
      bad++;
      continue;
    }
    final type = (map['type'] ?? '').toString();
    if (type == 'novel_progress' ||
        type == 'manga_progress' ||
        type == 'snapshot') {
      final e = ReaderEvent.fromJson(map);
      final w = e.work;
      if (w == null) {
        bad++;
        continue;
      }
      final cur = progress[w];
      if (cur == null || _compareProgress(e, cur) > 0) progress[w] = e;
      progressFolded[w] = (progressFolded[w] ?? 0) + 1;
    } else if (type == 'bookmark' || type == 'bookmark_delete') {
      final e = ReaderEvent.fromJson(map);
      final id = e.id;
      if (id == null) {
        bad++;
        continue;
      }
      final cur = bookmarkStates[id];
      if (cur == null || !e.ts.isBefore(cur.ts)) bookmarkStates[id] = e;
    } else {
      unknownRaw.add(line);
    }
  }

  final sortedWorks = progress.keys.toList()..sort();
  final sortedIds = bookmarkStates.keys.toList()..sort();
  final buf = StringBuffer();
  for (final w in sortedWorks) {
    final e = progress[w]!;
    buf.writeln(
      jsonEncode({
        'schema_version': e.schemaVersion,
        'ts': e.ts.toIso8601String(),
        'dev': e.dev,
        'type': 'snapshot',
        'work': w,
        'loc': e.loc,
        'folded_from': progressFolded[w],
      }),
    );
  }
  for (final id in sortedIds) {
    buf.writeln(jsonEncode(bookmarkStates[id]!.toJson()));
  }
  for (final line in unknownRaw) {
    buf.writeln(line);
  }
  return EventCompaction(
    content: buf.toString(),
    progressKept: sortedWorks.length,
    bookmarksKept: sortedIds.length,
    badDropped: bad,
  );
}

/// progress 决胜：ts 大者胜；ts 相同按 (dev, type) 字典序（§5.1，确定性）。
int _compareProgress(ReaderEvent a, ReaderEvent b) {
  final c = a.ts.compareTo(b.ts);
  if (c != 0) return c;
  return '${a.dev}|${a.type}'.compareTo('${b.dev}|${b.type}');
}

/// 纯重放（无副作用，可直接单测）：任何设备重放同一日志得同一结果。
ReplayResult replayEvents(Iterable<ReaderEvent> events) {
  final progress = <String, ReaderEvent>{};
  // 每个书签 id 的「最新状态事件」（bookmark 或 bookmark_delete 中 ts
  // 较新者）：删除后再来更旧的书签不会复活，更旧的删除也盖不掉新书签。
  final bookmarkStates = <String, ReaderEvent>{};
  for (final e in events) {
    if (e.isProgress) {
      final w = e.work;
      if (w == null) continue;
      final cur = progress[w];
      if (cur == null || _compareProgress(e, cur) > 0) progress[w] = e;
    } else if (e.type == 'bookmark' || e.type == 'bookmark_delete') {
      final id = e.id;
      if (id == null) continue;
      final cur = bookmarkStates[id];
      // ts 相同按行序后写覆盖（§5.1「同 id 后写覆盖」）
      if (cur == null || !e.ts.isBefore(cur.ts)) bookmarkStates[id] = e;
    }
  }
  final bookmarks = <String, ReaderEvent>{
    for (final e in bookmarkStates.entries)
      if (e.value.type == 'bookmark') e.key: e.value,
  };
  final deleted = <String>{
    for (final e in bookmarkStates.entries)
      if (e.value.type == 'bookmark_delete') e.key,
  };
  return ReplayResult(progress, bookmarks, deleted);
}

/// 追加事件到桶（读-改-写整对象；S3 语义无真追加，单人单写入者可接受，
/// 与索引写入同一约定）。首个事件容忍 events.jsonl 尚不存在。
Future<void> appendEvents(
  BucketClient client,
  List<Map<String, dynamic>> lines,
) async {
  if (lines.isEmpty) return;
  var existing = '';
  try {
    existing = utf8.decode(
      await client.getAll(LibraryPaths.eventsLog),
      allowMalformed: true,
    );
  } on ObjectNotFoundException {
    // 首个事件：文件还不存在
  }
  final buf = StringBuffer(existing);
  if (existing.isNotEmpty && !existing.endsWith('\n')) buf.write('\n');
  for (final l in lines) {
    buf.writeln(jsonEncode(l));
  }
  await client.put(
    LibraryPaths.eventsLog,
    Uint8List.fromList(utf8.encode(buf.toString())),
  );
}

/// 重放结果落库：本地行比事件新时保留本地（离线产生的数据不被旧事件
/// 回退）；其余按 LWW 幂等 upsert，删除集合清书签。
@visibleForTesting
Future<void> applyReplay(AppDatabase db, ReplayResult r) async {
  for (final e in r.progress.values) {
    final w = e.work;
    if (w == null) continue;
    final local = await (db.select(
      db.readingProgress,
    )..where((t) => t.workId.equals(w))).getSingleOrNull();
    if (local != null && local.updatedAt.isAfter(e.ts)) continue;
    await db
        .into(db.readingProgress)
        .insertOnConflictUpdate(
          ReadingProgressCompanion(
            workId: Value(w),
            loc: Value(jsonEncode(e.loc ?? const {})),
            dev: Value(e.dev),
            updatedAt: Value(e.ts),
          ),
        );
  }
  for (final e in r.bookmarks.values) {
    final id = e.id;
    if (id == null) continue;
    final local = await (db.select(
      db.bookmarks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (local != null && local.updatedAt.isAfter(e.ts)) continue;
    await db
        .into(db.bookmarks)
        .insertOnConflictUpdate(
          BookmarksCompanion(
            id: Value(id),
            workId: Value(e.work ?? ''),
            loc: Value(jsonEncode(e.loc ?? const {})),
            note: Value(e.note ?? ''),
            color: Value(e.color ?? 'red'),
            createdAt: Value(e.ts),
            updatedAt: Value(e.ts),
          ),
        );
  }
  for (final id in r.deletedBookmarkIds) {
    await (db.delete(db.bookmarks)..where((t) => t.id.equals(id))).go();
  }
}

class EventSyncReport {
  const EventSyncReport({
    required this.progressCount,
    required this.bookmarkCount,
    required this.deletedCount,
    required this.badLines,
  });

  final int progressCount;
  final int bookmarkCount;
  final int deletedCount;
  final List<BadLine> badLines;
}

/// 从桶拉取 events.jsonl 并重放落库（书架同步的第二步）。
/// 文件不存在视为无事件；坏行跳过计数（§5.2）。
Future<EventSyncReport> syncEventsFromBucket({
  required AppDatabase db,
  required BucketClient client,
}) async {
  Uint8List? bytes;
  try {
    bytes = await client.getAll(LibraryPaths.eventsLog);
  } on ObjectNotFoundException {
    return const EventSyncReport(
      progressCount: 0,
      bookmarkCount: 0,
      deletedCount: 0,
      badLines: [],
    );
  }
  final content = utf8.decode(bytes, allowMalformed: true);
  final (events, bad) = parseEventsLog(content);
  final r = replayEvents(events);
  await applyReplay(db, r);

  // 折叠：日志超过阈值时压成「必胜者名单」（O(作品数+书签数)）。
  // best-effort——失败不影响本次同步结果，下次再压。
  if (bytes.length > kEventsCompactThreshold) {
    try {
      final compacted = compactEvents(content);
      if (compacted.content != content) {
        await withRetry(
          () => client.put(
            LibraryPaths.eventsLog,
            Uint8List.fromList(utf8.encode(compacted.content)),
          ),
        );
        _log.info(
          'events compacted: ${compacted.progressKept} progress + '
          '${compacted.bookmarksKept} bookmarks kept, '
          '${compacted.badDropped} bad dropped',
        );
      }
    } on Object catch (e) {
      _log.warning('events compact failed: $e');
    }
  }

  return EventSyncReport(
    progressCount: r.progress.length,
    bookmarkCount: r.bookmarks.length,
    deletedCount: r.deletedBookmarkIds.length,
    badLines: bad,
  );
}

/// 阅读进度先落本地（离线/桶不可用都能记住位置）。
Future<void> saveProgressLocal(
  AppDatabase db,
  String workId,
  Map<String, dynamic> loc,
) async {
  await db
      .into(db.readingProgress)
      .insertOnConflictUpdate(
        ReadingProgressCompanion(
          workId: Value(workId),
          loc: Value(jsonEncode(loc)),
          updatedAt: Value(DateTime.now()),
        ),
      );
}

/// 退出阅读器时的最终保存：本地落库 + 尽力追加桶事件。
/// 任何失败只记日志——进度保存绝不能影响阅读器退出。
Future<void> saveProgressSafely(
  WidgetRef ref,
  Work work,
  Map<String, dynamic> loc, {
  required String dev,
}) async {
  try {
    await saveProgressLocal(ref.read(appDatabaseProvider), work.id, loc);
    final client = ref.read(bucketClientProvider);
    if (client == null) return;
    await appendEvents(client, [
      progressEvent(
        dev: dev,
        type: work.type == 'manga' ? 'manga_progress' : 'novel_progress',
        work: work.id,
        loc: loc,
      ),
    ]);
  } on Object catch (e) {
    _log.warning('progress save failed: $e');
  }
}

/// 书签/其他事件的最佳努力追加（本地已写，这里只补桶）。
Future<void> appendReaderEventSafely(
  WidgetRef ref,
  Map<String, dynamic> event,
) async {
  try {
    final client = ref.read(bucketClientProvider);
    if (client == null) return;
    await appendEvents(client, [event]);
  } on Object catch (e) {
    _log.warning('event append failed: $e');
  }
}

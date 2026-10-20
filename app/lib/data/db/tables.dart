import 'package:drift/drift.dart';

/// 本机漫画收藏夹；成员关系独立存储，同一漫画可属于多个收藏夹。
class MangaCollections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
}

class MangaCollectionEntries extends Table {
  IntColumn get collectionId => integer()();
  TextColumn get workId => text()();

  @override
  Set<Column> get primaryKey => {collectionId, workId};
}

/// 书架索引行（对应 works.jsonl，见设计文档 §4.1）。
class Works extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // novel | manga
  TextColumn get title => text()();
  TextColumn get titleJp => text().withDefault(const Constant(''))();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get series => text().withDefault(const Constant(''))();
  IntColumn get volume => integer().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get status => text().withDefault(const Constant('ongoing'))();
  IntColumn get totalChars => integer().nullable()();
  IntColumn get pages => integer().nullable()();
  TextColumn get lastUpdated => text().nullable()();
  TextColumn get cover => text().nullable()();
  TextColumn get origin => text().withDefault(const Constant('manual'))();
  BoolColumn get localOnly => boolean().withDefault(const Constant(false))();

  /// 是否有中文版本（未设置的作品按"有"处理，见设计文档 §4.1）。
  BoolColumn get hasZh => boolean().withDefault(const Constant(true))();

  /// 汉化质量：high | medium | low（默认 medium）。
  TextColumn get zhQuality => text().withDefault(const Constant('medium'))();

  /// 发布时间，精确到月（YYYY-MM）。
  TextColumn get publishedAt => text().nullable()();

  /// 完结时间，精确到月（YYYY-MM）。
  TextColumn get completedAt => text().nullable()();

  /// 同步时对象 etag，用于增量跳过。
  TextColumn get etag => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 书签当前态（由 events.jsonl 重放得到，见设计文档 §5.1）。
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text()();
  TextColumn get loc =>
      text()(); // JSON：{"vol":1,"ch":3,"offset":15200} 或 {"page":12}
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant('red'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 阅读进度当前态（按 work 维度 LWW，见设计文档 §5.1）。
class ReadingProgress extends Table {
  TextColumn get workId => text()();
  TextColumn get loc => text()(); // JSON，同书签坐标
  TextColumn get dev => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {workId};
}

/// 设置项（设计文档 §10）。scope: device | synced。
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get scope => text().withDefault(const Constant('device'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// JM 下载任务（持久化：进程被杀/闪退后恢复列表并续跑，见设计文档 §14）。
/// status: downloading | compressing | done | failed
@DataClassName('JmTaskRow')
class JmTasks extends Table {
  TextColumn get albumId => text()();
  TextColumn get title => text()();
  TextColumn get status => text()();
  TextColumn get phase => text().withDefault(const Constant(''))();
  TextColumn get error => text().nullable()();
  IntColumn get pages => integer().nullable()();
  IntColumn get keptOriginal => integer().nullable()();

  /// 启动时的配置快照（恢复续跑/重试用）。
  TextColumn get ffmpegPath => text().withDefault(const Constant(''))();
  TextColumn get proxy => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {albumId};
}

/// 同步水位表：每种同步流一行（当前仅 works_index）。
class SyncState extends Table {
  TextColumn get name => text()();
  IntColumn get byteOffset => integer().withDefault(const Constant(0))();
  IntColumn get lineCount => integer().withDefault(const Constant(0))();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {name};
}

/// 书源（M5，设计文档 §8）：内置源只存覆盖状态（json 为空走 assets），
/// 用户导入源存完整规则 JSON；同 sourceId 用户源覆盖内置规则。
class NovelSources extends Table {
  TextColumn get sourceId => text()();
  TextColumn get name => text()();
  TextColumn get json => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get disableReason => text().withDefault(const Constant(''))();
  TextColumn get lastTestResult => text().withDefault(const Constant(''))();
  DateTimeColumn get lastTestedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sourceId};
}

/// 小说书源下载任务（持久化 + 中断续跑，语义对齐 JmTasks）。
/// status: downloading | done | failed
@DataClassName('NovelTaskRow')
class NovelTasks extends Table {
  TextColumn get workId => text()();
  TextColumn get title => text()();
  TextColumn get status => text()();
  TextColumn get phase => text().withDefault(const Constant(''))();
  TextColumn get error => text().nullable()();

  /// 缺章清单摘要（终态 failed 时）："3,17,42" 或空。
  TextColumn get failedChapters => text().withDefault(const Constant(''))();
  IntColumn get totalChapters => integer().nullable()();
  IntColumn get doneChapters => integer().nullable()();

  /// 启动配置快照（恢复续跑/重试的完整输入，JSON）。
  TextColumn get snapshot => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {workId};
}

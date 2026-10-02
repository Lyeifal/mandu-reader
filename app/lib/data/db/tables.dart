import 'package:drift/drift.dart';

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

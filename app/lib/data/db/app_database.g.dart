// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WorksTable extends Works with TableInfo<$WorksTable, Work> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleJpMeta = const VerificationMeta(
    'titleJp',
  );
  @override
  late final GeneratedColumn<String> titleJp = GeneratedColumn<String>(
    'title_jp',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _seriesMeta = const VerificationMeta('series');
  @override
  late final GeneratedColumn<String> series = GeneratedColumn<String>(
    'series',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<int> volume = GeneratedColumn<int>(
    'volume',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ongoing'),
  );
  static const VerificationMeta _totalCharsMeta = const VerificationMeta(
    'totalChars',
  );
  @override
  late final GeneratedColumn<int> totalChars = GeneratedColumn<int>(
    'total_chars',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pagesMeta = const VerificationMeta('pages');
  @override
  late final GeneratedColumn<int> pages = GeneratedColumn<int>(
    'pages',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<String> lastUpdated = GeneratedColumn<String>(
    'last_updated',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _localOnlyMeta = const VerificationMeta(
    'localOnly',
  );
  @override
  late final GeneratedColumn<bool> localOnly = GeneratedColumn<bool>(
    'local_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_only" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasZhMeta = const VerificationMeta('hasZh');
  @override
  late final GeneratedColumn<bool> hasZh = GeneratedColumn<bool>(
    'has_zh',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_zh" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _zhQualityMeta = const VerificationMeta(
    'zhQuality',
  );
  @override
  late final GeneratedColumn<String> zhQuality = GeneratedColumn<String>(
    'zh_quality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('medium'),
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<String> publishedAt = GeneratedColumn<String>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    titleJp,
    author,
    series,
    volume,
    tags,
    status,
    totalChars,
    pages,
    lastUpdated,
    cover,
    origin,
    localOnly,
    hasZh,
    zhQuality,
    publishedAt,
    completedAt,
    etag,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'works';
  @override
  VerificationContext validateIntegrity(
    Insertable<Work> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_jp')) {
      context.handle(
        _titleJpMeta,
        titleJp.isAcceptableOrUnknown(data['title_jp']!, _titleJpMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('series')) {
      context.handle(
        _seriesMeta,
        series.isAcceptableOrUnknown(data['series']!, _seriesMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('total_chars')) {
      context.handle(
        _totalCharsMeta,
        totalChars.isAcceptableOrUnknown(data['total_chars']!, _totalCharsMeta),
      );
    }
    if (data.containsKey('pages')) {
      context.handle(
        _pagesMeta,
        pages.isAcceptableOrUnknown(data['pages']!, _pagesMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('local_only')) {
      context.handle(
        _localOnlyMeta,
        localOnly.isAcceptableOrUnknown(data['local_only']!, _localOnlyMeta),
      );
    }
    if (data.containsKey('has_zh')) {
      context.handle(
        _hasZhMeta,
        hasZh.isAcceptableOrUnknown(data['has_zh']!, _hasZhMeta),
      );
    }
    if (data.containsKey('zh_quality')) {
      context.handle(
        _zhQualityMeta,
        zhQuality.isAcceptableOrUnknown(data['zh_quality']!, _zhQualityMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Work map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Work(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleJp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_jp'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      series: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      totalChars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chars'],
      ),
      pages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages'],
      ),
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_updated'],
      ),
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      localOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_only'],
      )!,
      hasZh: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_zh'],
      )!,
      zhQuality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zh_quality'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}published_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $WorksTable createAlias(String alias) {
    return $WorksTable(attachedDatabase, alias);
  }
}

class Work extends DataClass implements Insertable<Work> {
  final String id;
  final String type;
  final String title;
  final String titleJp;
  final String author;
  final String series;
  final int? volume;
  final String tags;
  final String status;
  final int? totalChars;
  final int? pages;
  final String? lastUpdated;
  final String? cover;
  final String origin;
  final bool localOnly;

  /// 是否有中文版本（未设置的作品按"有"处理，见设计文档 §4.1）。
  final bool hasZh;

  /// 汉化质量：high | medium | low（默认 medium）。
  final String zhQuality;

  /// 发布时间，精确到月（YYYY-MM）。
  final String? publishedAt;

  /// 完结时间，精确到月（YYYY-MM）。
  final String? completedAt;

  /// 同步时对象 etag，用于增量跳过。
  final String? etag;
  final DateTime? syncedAt;
  const Work({
    required this.id,
    required this.type,
    required this.title,
    required this.titleJp,
    required this.author,
    required this.series,
    this.volume,
    required this.tags,
    required this.status,
    this.totalChars,
    this.pages,
    this.lastUpdated,
    this.cover,
    required this.origin,
    required this.localOnly,
    required this.hasZh,
    required this.zhQuality,
    this.publishedAt,
    this.completedAt,
    this.etag,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['title_jp'] = Variable<String>(titleJp);
    map['author'] = Variable<String>(author);
    map['series'] = Variable<String>(series);
    if (!nullToAbsent || volume != null) {
      map['volume'] = Variable<int>(volume);
    }
    map['tags'] = Variable<String>(tags);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || totalChars != null) {
      map['total_chars'] = Variable<int>(totalChars);
    }
    if (!nullToAbsent || pages != null) {
      map['pages'] = Variable<int>(pages);
    }
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<String>(lastUpdated);
    }
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    map['origin'] = Variable<String>(origin);
    map['local_only'] = Variable<bool>(localOnly);
    map['has_zh'] = Variable<bool>(hasZh);
    map['zh_quality'] = Variable<String>(zhQuality);
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<String>(publishedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  WorksCompanion toCompanion(bool nullToAbsent) {
    return WorksCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      titleJp: Value(titleJp),
      author: Value(author),
      series: Value(series),
      volume: volume == null && nullToAbsent
          ? const Value.absent()
          : Value(volume),
      tags: Value(tags),
      status: Value(status),
      totalChars: totalChars == null && nullToAbsent
          ? const Value.absent()
          : Value(totalChars),
      pages: pages == null && nullToAbsent
          ? const Value.absent()
          : Value(pages),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      origin: Value(origin),
      localOnly: Value(localOnly),
      hasZh: Value(hasZh),
      zhQuality: Value(zhQuality),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory Work.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Work(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      titleJp: serializer.fromJson<String>(json['titleJp']),
      author: serializer.fromJson<String>(json['author']),
      series: serializer.fromJson<String>(json['series']),
      volume: serializer.fromJson<int?>(json['volume']),
      tags: serializer.fromJson<String>(json['tags']),
      status: serializer.fromJson<String>(json['status']),
      totalChars: serializer.fromJson<int?>(json['totalChars']),
      pages: serializer.fromJson<int?>(json['pages']),
      lastUpdated: serializer.fromJson<String?>(json['lastUpdated']),
      cover: serializer.fromJson<String?>(json['cover']),
      origin: serializer.fromJson<String>(json['origin']),
      localOnly: serializer.fromJson<bool>(json['localOnly']),
      hasZh: serializer.fromJson<bool>(json['hasZh']),
      zhQuality: serializer.fromJson<String>(json['zhQuality']),
      publishedAt: serializer.fromJson<String?>(json['publishedAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      etag: serializer.fromJson<String?>(json['etag']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'titleJp': serializer.toJson<String>(titleJp),
      'author': serializer.toJson<String>(author),
      'series': serializer.toJson<String>(series),
      'volume': serializer.toJson<int?>(volume),
      'tags': serializer.toJson<String>(tags),
      'status': serializer.toJson<String>(status),
      'totalChars': serializer.toJson<int?>(totalChars),
      'pages': serializer.toJson<int?>(pages),
      'lastUpdated': serializer.toJson<String?>(lastUpdated),
      'cover': serializer.toJson<String?>(cover),
      'origin': serializer.toJson<String>(origin),
      'localOnly': serializer.toJson<bool>(localOnly),
      'hasZh': serializer.toJson<bool>(hasZh),
      'zhQuality': serializer.toJson<String>(zhQuality),
      'publishedAt': serializer.toJson<String?>(publishedAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'etag': serializer.toJson<String?>(etag),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  Work copyWith({
    String? id,
    String? type,
    String? title,
    String? titleJp,
    String? author,
    String? series,
    Value<int?> volume = const Value.absent(),
    String? tags,
    String? status,
    Value<int?> totalChars = const Value.absent(),
    Value<int?> pages = const Value.absent(),
    Value<String?> lastUpdated = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    String? origin,
    bool? localOnly,
    bool? hasZh,
    String? zhQuality,
    Value<String?> publishedAt = const Value.absent(),
    Value<String?> completedAt = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => Work(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    titleJp: titleJp ?? this.titleJp,
    author: author ?? this.author,
    series: series ?? this.series,
    volume: volume.present ? volume.value : this.volume,
    tags: tags ?? this.tags,
    status: status ?? this.status,
    totalChars: totalChars.present ? totalChars.value : this.totalChars,
    pages: pages.present ? pages.value : this.pages,
    lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
    cover: cover.present ? cover.value : this.cover,
    origin: origin ?? this.origin,
    localOnly: localOnly ?? this.localOnly,
    hasZh: hasZh ?? this.hasZh,
    zhQuality: zhQuality ?? this.zhQuality,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    etag: etag.present ? etag.value : this.etag,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  Work copyWithCompanion(WorksCompanion data) {
    return Work(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      titleJp: data.titleJp.present ? data.titleJp.value : this.titleJp,
      author: data.author.present ? data.author.value : this.author,
      series: data.series.present ? data.series.value : this.series,
      volume: data.volume.present ? data.volume.value : this.volume,
      tags: data.tags.present ? data.tags.value : this.tags,
      status: data.status.present ? data.status.value : this.status,
      totalChars: data.totalChars.present
          ? data.totalChars.value
          : this.totalChars,
      pages: data.pages.present ? data.pages.value : this.pages,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
      cover: data.cover.present ? data.cover.value : this.cover,
      origin: data.origin.present ? data.origin.value : this.origin,
      localOnly: data.localOnly.present ? data.localOnly.value : this.localOnly,
      hasZh: data.hasZh.present ? data.hasZh.value : this.hasZh,
      zhQuality: data.zhQuality.present ? data.zhQuality.value : this.zhQuality,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      etag: data.etag.present ? data.etag.value : this.etag,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Work(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('titleJp: $titleJp, ')
          ..write('author: $author, ')
          ..write('series: $series, ')
          ..write('volume: $volume, ')
          ..write('tags: $tags, ')
          ..write('status: $status, ')
          ..write('totalChars: $totalChars, ')
          ..write('pages: $pages, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('cover: $cover, ')
          ..write('origin: $origin, ')
          ..write('localOnly: $localOnly, ')
          ..write('hasZh: $hasZh, ')
          ..write('zhQuality: $zhQuality, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('etag: $etag, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    title,
    titleJp,
    author,
    series,
    volume,
    tags,
    status,
    totalChars,
    pages,
    lastUpdated,
    cover,
    origin,
    localOnly,
    hasZh,
    zhQuality,
    publishedAt,
    completedAt,
    etag,
    syncedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Work &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.titleJp == this.titleJp &&
          other.author == this.author &&
          other.series == this.series &&
          other.volume == this.volume &&
          other.tags == this.tags &&
          other.status == this.status &&
          other.totalChars == this.totalChars &&
          other.pages == this.pages &&
          other.lastUpdated == this.lastUpdated &&
          other.cover == this.cover &&
          other.origin == this.origin &&
          other.localOnly == this.localOnly &&
          other.hasZh == this.hasZh &&
          other.zhQuality == this.zhQuality &&
          other.publishedAt == this.publishedAt &&
          other.completedAt == this.completedAt &&
          other.etag == this.etag &&
          other.syncedAt == this.syncedAt);
}

class WorksCompanion extends UpdateCompanion<Work> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> title;
  final Value<String> titleJp;
  final Value<String> author;
  final Value<String> series;
  final Value<int?> volume;
  final Value<String> tags;
  final Value<String> status;
  final Value<int?> totalChars;
  final Value<int?> pages;
  final Value<String?> lastUpdated;
  final Value<String?> cover;
  final Value<String> origin;
  final Value<bool> localOnly;
  final Value<bool> hasZh;
  final Value<String> zhQuality;
  final Value<String?> publishedAt;
  final Value<String?> completedAt;
  final Value<String?> etag;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const WorksCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.titleJp = const Value.absent(),
    this.author = const Value.absent(),
    this.series = const Value.absent(),
    this.volume = const Value.absent(),
    this.tags = const Value.absent(),
    this.status = const Value.absent(),
    this.totalChars = const Value.absent(),
    this.pages = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.cover = const Value.absent(),
    this.origin = const Value.absent(),
    this.localOnly = const Value.absent(),
    this.hasZh = const Value.absent(),
    this.zhQuality = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.etag = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorksCompanion.insert({
    required String id,
    required String type,
    required String title,
    this.titleJp = const Value.absent(),
    this.author = const Value.absent(),
    this.series = const Value.absent(),
    this.volume = const Value.absent(),
    this.tags = const Value.absent(),
    this.status = const Value.absent(),
    this.totalChars = const Value.absent(),
    this.pages = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.cover = const Value.absent(),
    this.origin = const Value.absent(),
    this.localOnly = const Value.absent(),
    this.hasZh = const Value.absent(),
    this.zhQuality = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.etag = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       title = Value(title);
  static Insertable<Work> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? titleJp,
    Expression<String>? author,
    Expression<String>? series,
    Expression<int>? volume,
    Expression<String>? tags,
    Expression<String>? status,
    Expression<int>? totalChars,
    Expression<int>? pages,
    Expression<String>? lastUpdated,
    Expression<String>? cover,
    Expression<String>? origin,
    Expression<bool>? localOnly,
    Expression<bool>? hasZh,
    Expression<String>? zhQuality,
    Expression<String>? publishedAt,
    Expression<String>? completedAt,
    Expression<String>? etag,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (titleJp != null) 'title_jp': titleJp,
      if (author != null) 'author': author,
      if (series != null) 'series': series,
      if (volume != null) 'volume': volume,
      if (tags != null) 'tags': tags,
      if (status != null) 'status': status,
      if (totalChars != null) 'total_chars': totalChars,
      if (pages != null) 'pages': pages,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (cover != null) 'cover': cover,
      if (origin != null) 'origin': origin,
      if (localOnly != null) 'local_only': localOnly,
      if (hasZh != null) 'has_zh': hasZh,
      if (zhQuality != null) 'zh_quality': zhQuality,
      if (publishedAt != null) 'published_at': publishedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (etag != null) 'etag': etag,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorksCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? title,
    Value<String>? titleJp,
    Value<String>? author,
    Value<String>? series,
    Value<int?>? volume,
    Value<String>? tags,
    Value<String>? status,
    Value<int?>? totalChars,
    Value<int?>? pages,
    Value<String?>? lastUpdated,
    Value<String?>? cover,
    Value<String>? origin,
    Value<bool>? localOnly,
    Value<bool>? hasZh,
    Value<String>? zhQuality,
    Value<String?>? publishedAt,
    Value<String?>? completedAt,
    Value<String?>? etag,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return WorksCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      titleJp: titleJp ?? this.titleJp,
      author: author ?? this.author,
      series: series ?? this.series,
      volume: volume ?? this.volume,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      totalChars: totalChars ?? this.totalChars,
      pages: pages ?? this.pages,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      cover: cover ?? this.cover,
      origin: origin ?? this.origin,
      localOnly: localOnly ?? this.localOnly,
      hasZh: hasZh ?? this.hasZh,
      zhQuality: zhQuality ?? this.zhQuality,
      publishedAt: publishedAt ?? this.publishedAt,
      completedAt: completedAt ?? this.completedAt,
      etag: etag ?? this.etag,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleJp.present) {
      map['title_jp'] = Variable<String>(titleJp.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (series.present) {
      map['series'] = Variable<String>(series.value);
    }
    if (volume.present) {
      map['volume'] = Variable<int>(volume.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (totalChars.present) {
      map['total_chars'] = Variable<int>(totalChars.value);
    }
    if (pages.present) {
      map['pages'] = Variable<int>(pages.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<String>(lastUpdated.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (localOnly.present) {
      map['local_only'] = Variable<bool>(localOnly.value);
    }
    if (hasZh.present) {
      map['has_zh'] = Variable<bool>(hasZh.value);
    }
    if (zhQuality.present) {
      map['zh_quality'] = Variable<String>(zhQuality.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<String>(publishedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorksCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('titleJp: $titleJp, ')
          ..write('author: $author, ')
          ..write('series: $series, ')
          ..write('volume: $volume, ')
          ..write('tags: $tags, ')
          ..write('status: $status, ')
          ..write('totalChars: $totalChars, ')
          ..write('pages: $pages, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('cover: $cover, ')
          ..write('origin: $origin, ')
          ..write('localOnly: $localOnly, ')
          ..write('hasZh: $hasZh, ')
          ..write('zhQuality: $zhQuality, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('etag: $etag, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workIdMeta = const VerificationMeta('workId');
  @override
  late final GeneratedColumn<String> workId = GeneratedColumn<String>(
    'work_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locMeta = const VerificationMeta('loc');
  @override
  late final GeneratedColumn<String> loc = GeneratedColumn<String>(
    'loc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('red'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workId,
    loc,
    note,
    color,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('work_id')) {
      context.handle(
        _workIdMeta,
        workId.isAcceptableOrUnknown(data['work_id']!, _workIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workIdMeta);
    }
    if (data.containsKey('loc')) {
      context.handle(
        _locMeta,
        loc.isAcceptableOrUnknown(data['loc']!, _locMeta),
      );
    } else if (isInserting) {
      context.missing(_locMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_id'],
      )!,
      loc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loc'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final String id;
  final String workId;
  final String loc;
  final String note;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Bookmark({
    required this.id,
    required this.workId,
    required this.loc,
    required this.note,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['work_id'] = Variable<String>(workId);
    map['loc'] = Variable<String>(loc);
    map['note'] = Variable<String>(note);
    map['color'] = Variable<String>(color);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      workId: Value(workId),
      loc: Value(loc),
      note: Value(note),
      color: Value(color),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<String>(json['id']),
      workId: serializer.fromJson<String>(json['workId']),
      loc: serializer.fromJson<String>(json['loc']),
      note: serializer.fromJson<String>(json['note']),
      color: serializer.fromJson<String>(json['color']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workId': serializer.toJson<String>(workId),
      'loc': serializer.toJson<String>(loc),
      'note': serializer.toJson<String>(note),
      'color': serializer.toJson<String>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Bookmark copyWith({
    String? id,
    String? workId,
    String? loc,
    String? note,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Bookmark(
    id: id ?? this.id,
    workId: workId ?? this.workId,
    loc: loc ?? this.loc,
    note: note ?? this.note,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      workId: data.workId.present ? data.workId.value : this.workId,
      loc: data.loc.present ? data.loc.value : this.loc,
      note: data.note.present ? data.note.value : this.note,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('workId: $workId, ')
          ..write('loc: $loc, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, workId, loc, note, color, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.workId == this.workId &&
          other.loc == this.loc &&
          other.note == this.note &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> id;
  final Value<String> workId;
  final Value<String> loc;
  final Value<String> note;
  final Value<String> color;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.workId = const Value.absent(),
    this.loc = const Value.absent(),
    this.note = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String workId,
    required String loc,
    this.note = const Value.absent(),
    this.color = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workId = Value(workId),
       loc = Value(loc),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Bookmark> custom({
    Expression<String>? id,
    Expression<String>? workId,
    Expression<String>? loc,
    Expression<String>? note,
    Expression<String>? color,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workId != null) 'work_id': workId,
      if (loc != null) 'loc': loc,
      if (note != null) 'note': note,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? workId,
    Value<String>? loc,
    Value<String>? note,
    Value<String>? color,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      loc: loc ?? this.loc,
      note: note ?? this.note,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workId.present) {
      map['work_id'] = Variable<String>(workId.value);
    }
    if (loc.present) {
      map['loc'] = Variable<String>(loc.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('workId: $workId, ')
          ..write('loc: $loc, ')
          ..write('note: $note, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workIdMeta = const VerificationMeta('workId');
  @override
  late final GeneratedColumn<String> workId = GeneratedColumn<String>(
    'work_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locMeta = const VerificationMeta('loc');
  @override
  late final GeneratedColumn<String> loc = GeneratedColumn<String>(
    'loc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _devMeta = const VerificationMeta('dev');
  @override
  late final GeneratedColumn<String> dev = GeneratedColumn<String>(
    'dev',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [workId, loc, dev, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('work_id')) {
      context.handle(
        _workIdMeta,
        workId.isAcceptableOrUnknown(data['work_id']!, _workIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workIdMeta);
    }
    if (data.containsKey('loc')) {
      context.handle(
        _locMeta,
        loc.isAcceptableOrUnknown(data['loc']!, _locMeta),
      );
    } else if (isInserting) {
      context.missing(_locMeta);
    }
    if (data.containsKey('dev')) {
      context.handle(
        _devMeta,
        dev.isAcceptableOrUnknown(data['dev']!, _devMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workId};
  @override
  ReadingProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressData(
      workId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_id'],
      )!,
      loc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loc'],
      )!,
      dev: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dev'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressData extends DataClass
    implements Insertable<ReadingProgressData> {
  final String workId;
  final String loc;
  final String dev;
  final DateTime updatedAt;
  const ReadingProgressData({
    required this.workId,
    required this.loc,
    required this.dev,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['work_id'] = Variable<String>(workId);
    map['loc'] = Variable<String>(loc);
    map['dev'] = Variable<String>(dev);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      workId: Value(workId),
      loc: Value(loc),
      dev: Value(dev),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressData(
      workId: serializer.fromJson<String>(json['workId']),
      loc: serializer.fromJson<String>(json['loc']),
      dev: serializer.fromJson<String>(json['dev']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workId': serializer.toJson<String>(workId),
      'loc': serializer.toJson<String>(loc),
      'dev': serializer.toJson<String>(dev),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressData copyWith({
    String? workId,
    String? loc,
    String? dev,
    DateTime? updatedAt,
  }) => ReadingProgressData(
    workId: workId ?? this.workId,
    loc: loc ?? this.loc,
    dev: dev ?? this.dev,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressData copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressData(
      workId: data.workId.present ? data.workId.value : this.workId,
      loc: data.loc.present ? data.loc.value : this.loc,
      dev: data.dev.present ? data.dev.value : this.dev,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressData(')
          ..write('workId: $workId, ')
          ..write('loc: $loc, ')
          ..write('dev: $dev, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(workId, loc, dev, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressData &&
          other.workId == this.workId &&
          other.loc == this.loc &&
          other.dev == this.dev &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressData> {
  final Value<String> workId;
  final Value<String> loc;
  final Value<String> dev;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingProgressCompanion({
    this.workId = const Value.absent(),
    this.loc = const Value.absent(),
    this.dev = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    required String workId,
    required String loc,
    this.dev = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : workId = Value(workId),
       loc = Value(loc),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingProgressData> custom({
    Expression<String>? workId,
    Expression<String>? loc,
    Expression<String>? dev,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workId != null) 'work_id': workId,
      if (loc != null) 'loc': loc,
      if (dev != null) 'dev': dev,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<String>? workId,
    Value<String>? loc,
    Value<String>? dev,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReadingProgressCompanion(
      workId: workId ?? this.workId,
      loc: loc ?? this.loc,
      dev: dev ?? this.dev,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workId.present) {
      map['work_id'] = Variable<String>(workId.value);
    }
    if (loc.present) {
      map['loc'] = Variable<String>(loc.value);
    }
    if (dev.present) {
      map['dev'] = Variable<String>(dev.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('workId: $workId, ')
          ..write('loc: $loc, ')
          ..write('dev: $dev, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('device'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, scope, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  final String scope;
  final DateTime updatedAt;
  const Setting({
    required this.key,
    required this.value,
    required this.scope,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['scope'] = Variable<String>(scope);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
      scope: Value(scope),
      updatedAt: Value(updatedAt),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      scope: serializer.fromJson<String>(json['scope']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'scope': serializer.toJson<String>(scope),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Setting copyWith({
    String? key,
    String? value,
    String? scope,
    DateTime? updatedAt,
  }) => Setting(
    key: key ?? this.key,
    value: value ?? this.value,
    scope: scope ?? this.scope,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      scope: data.scope.present ? data.scope.value : this.scope,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('scope: $scope, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, scope, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.key == this.key &&
          other.value == this.value &&
          other.scope == this.scope &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<String> scope;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.scope = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.scope = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? scope,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (scope != null) 'scope': scope,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<String>? scope,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      scope: scope ?? this.scope,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('scope: $scope, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteOffsetMeta = const VerificationMeta(
    'byteOffset',
  );
  @override
  late final GeneratedColumn<int> byteOffset = GeneratedColumn<int>(
    'byte_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lineCountMeta = const VerificationMeta(
    'lineCount',
  );
  @override
  late final GeneratedColumn<int> lineCount = GeneratedColumn<int>(
    'line_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    name,
    byteOffset,
    lineCount,
    etag,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('byte_offset')) {
      context.handle(
        _byteOffsetMeta,
        byteOffset.isAcceptableOrUnknown(data['byte_offset']!, _byteOffsetMeta),
      );
    }
    if (data.containsKey('line_count')) {
      context.handle(
        _lineCountMeta,
        lineCount.isAcceptableOrUnknown(data['line_count']!, _lineCountMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      byteOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_offset'],
      )!,
      lineCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_count'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String name;
  final int byteOffset;
  final int lineCount;
  final String? etag;
  final DateTime? syncedAt;
  const SyncStateData({
    required this.name,
    required this.byteOffset,
    required this.lineCount,
    this.etag,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['byte_offset'] = Variable<int>(byteOffset);
    map['line_count'] = Variable<int>(lineCount);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      name: Value(name),
      byteOffset: Value(byteOffset),
      lineCount: Value(lineCount),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      name: serializer.fromJson<String>(json['name']),
      byteOffset: serializer.fromJson<int>(json['byteOffset']),
      lineCount: serializer.fromJson<int>(json['lineCount']),
      etag: serializer.fromJson<String?>(json['etag']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'byteOffset': serializer.toJson<int>(byteOffset),
      'lineCount': serializer.toJson<int>(lineCount),
      'etag': serializer.toJson<String?>(etag),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  SyncStateData copyWith({
    String? name,
    int? byteOffset,
    int? lineCount,
    Value<String?> etag = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => SyncStateData(
    name: name ?? this.name,
    byteOffset: byteOffset ?? this.byteOffset,
    lineCount: lineCount ?? this.lineCount,
    etag: etag.present ? etag.value : this.etag,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      name: data.name.present ? data.name.value : this.name,
      byteOffset: data.byteOffset.present
          ? data.byteOffset.value
          : this.byteOffset,
      lineCount: data.lineCount.present ? data.lineCount.value : this.lineCount,
      etag: data.etag.present ? data.etag.value : this.etag,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('name: $name, ')
          ..write('byteOffset: $byteOffset, ')
          ..write('lineCount: $lineCount, ')
          ..write('etag: $etag, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, byteOffset, lineCount, etag, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.name == this.name &&
          other.byteOffset == this.byteOffset &&
          other.lineCount == this.lineCount &&
          other.etag == this.etag &&
          other.syncedAt == this.syncedAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> name;
  final Value<int> byteOffset;
  final Value<int> lineCount;
  final Value<String?> etag;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.name = const Value.absent(),
    this.byteOffset = const Value.absent(),
    this.lineCount = const Value.absent(),
    this.etag = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String name,
    this.byteOffset = const Value.absent(),
    this.lineCount = const Value.absent(),
    this.etag = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SyncStateData> custom({
    Expression<String>? name,
    Expression<int>? byteOffset,
    Expression<int>? lineCount,
    Expression<String>? etag,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (byteOffset != null) 'byte_offset': byteOffset,
      if (lineCount != null) 'line_count': lineCount,
      if (etag != null) 'etag': etag,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? name,
    Value<int>? byteOffset,
    Value<int>? lineCount,
    Value<String?>? etag,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      name: name ?? this.name,
      byteOffset: byteOffset ?? this.byteOffset,
      lineCount: lineCount ?? this.lineCount,
      etag: etag ?? this.etag,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (byteOffset.present) {
      map['byte_offset'] = Variable<int>(byteOffset.value);
    }
    if (lineCount.present) {
      map['line_count'] = Variable<int>(lineCount.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('name: $name, ')
          ..write('byteOffset: $byteOffset, ')
          ..write('lineCount: $lineCount, ')
          ..write('etag: $etag, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JmTasksTable extends JmTasks with TableInfo<$JmTasksTable, JmTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JmTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pagesMeta = const VerificationMeta('pages');
  @override
  late final GeneratedColumn<int> pages = GeneratedColumn<int>(
    'pages',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keptOriginalMeta = const VerificationMeta(
    'keptOriginal',
  );
  @override
  late final GeneratedColumn<int> keptOriginal = GeneratedColumn<int>(
    'kept_original',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ffmpegPathMeta = const VerificationMeta(
    'ffmpegPath',
  );
  @override
  late final GeneratedColumn<String> ffmpegPath = GeneratedColumn<String>(
    'ffmpeg_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _proxyMeta = const VerificationMeta('proxy');
  @override
  late final GeneratedColumn<String> proxy = GeneratedColumn<String>(
    'proxy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    albumId,
    title,
    status,
    phase,
    error,
    pages,
    keptOriginal,
    ffmpegPath,
    proxy,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jm_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<JmTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('pages')) {
      context.handle(
        _pagesMeta,
        pages.isAcceptableOrUnknown(data['pages']!, _pagesMeta),
      );
    }
    if (data.containsKey('kept_original')) {
      context.handle(
        _keptOriginalMeta,
        keptOriginal.isAcceptableOrUnknown(
          data['kept_original']!,
          _keptOriginalMeta,
        ),
      );
    }
    if (data.containsKey('ffmpeg_path')) {
      context.handle(
        _ffmpegPathMeta,
        ffmpegPath.isAcceptableOrUnknown(data['ffmpeg_path']!, _ffmpegPathMeta),
      );
    }
    if (data.containsKey('proxy')) {
      context.handle(
        _proxyMeta,
        proxy.isAcceptableOrUnknown(data['proxy']!, _proxyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {albumId};
  @override
  JmTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JmTaskRow(
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      pages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages'],
      ),
      keptOriginal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kept_original'],
      ),
      ffmpegPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ffmpeg_path'],
      )!,
      proxy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $JmTasksTable createAlias(String alias) {
    return $JmTasksTable(attachedDatabase, alias);
  }
}

class JmTaskRow extends DataClass implements Insertable<JmTaskRow> {
  final String albumId;
  final String title;
  final String status;
  final String phase;
  final String? error;
  final int? pages;
  final int? keptOriginal;

  /// 启动时的配置快照（恢复续跑/重试用）。
  final String ffmpegPath;
  final String proxy;
  final DateTime updatedAt;
  const JmTaskRow({
    required this.albumId,
    required this.title,
    required this.status,
    required this.phase,
    this.error,
    this.pages,
    this.keptOriginal,
    required this.ffmpegPath,
    required this.proxy,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['album_id'] = Variable<String>(albumId);
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    map['phase'] = Variable<String>(phase);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || pages != null) {
      map['pages'] = Variable<int>(pages);
    }
    if (!nullToAbsent || keptOriginal != null) {
      map['kept_original'] = Variable<int>(keptOriginal);
    }
    map['ffmpeg_path'] = Variable<String>(ffmpegPath);
    map['proxy'] = Variable<String>(proxy);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  JmTasksCompanion toCompanion(bool nullToAbsent) {
    return JmTasksCompanion(
      albumId: Value(albumId),
      title: Value(title),
      status: Value(status),
      phase: Value(phase),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      pages: pages == null && nullToAbsent
          ? const Value.absent()
          : Value(pages),
      keptOriginal: keptOriginal == null && nullToAbsent
          ? const Value.absent()
          : Value(keptOriginal),
      ffmpegPath: Value(ffmpegPath),
      proxy: Value(proxy),
      updatedAt: Value(updatedAt),
    );
  }

  factory JmTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JmTaskRow(
      albumId: serializer.fromJson<String>(json['albumId']),
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      phase: serializer.fromJson<String>(json['phase']),
      error: serializer.fromJson<String?>(json['error']),
      pages: serializer.fromJson<int?>(json['pages']),
      keptOriginal: serializer.fromJson<int?>(json['keptOriginal']),
      ffmpegPath: serializer.fromJson<String>(json['ffmpegPath']),
      proxy: serializer.fromJson<String>(json['proxy']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'albumId': serializer.toJson<String>(albumId),
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'phase': serializer.toJson<String>(phase),
      'error': serializer.toJson<String?>(error),
      'pages': serializer.toJson<int?>(pages),
      'keptOriginal': serializer.toJson<int?>(keptOriginal),
      'ffmpegPath': serializer.toJson<String>(ffmpegPath),
      'proxy': serializer.toJson<String>(proxy),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  JmTaskRow copyWith({
    String? albumId,
    String? title,
    String? status,
    String? phase,
    Value<String?> error = const Value.absent(),
    Value<int?> pages = const Value.absent(),
    Value<int?> keptOriginal = const Value.absent(),
    String? ffmpegPath,
    String? proxy,
    DateTime? updatedAt,
  }) => JmTaskRow(
    albumId: albumId ?? this.albumId,
    title: title ?? this.title,
    status: status ?? this.status,
    phase: phase ?? this.phase,
    error: error.present ? error.value : this.error,
    pages: pages.present ? pages.value : this.pages,
    keptOriginal: keptOriginal.present ? keptOriginal.value : this.keptOriginal,
    ffmpegPath: ffmpegPath ?? this.ffmpegPath,
    proxy: proxy ?? this.proxy,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  JmTaskRow copyWithCompanion(JmTasksCompanion data) {
    return JmTaskRow(
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      phase: data.phase.present ? data.phase.value : this.phase,
      error: data.error.present ? data.error.value : this.error,
      pages: data.pages.present ? data.pages.value : this.pages,
      keptOriginal: data.keptOriginal.present
          ? data.keptOriginal.value
          : this.keptOriginal,
      ffmpegPath: data.ffmpegPath.present
          ? data.ffmpegPath.value
          : this.ffmpegPath,
      proxy: data.proxy.present ? data.proxy.value : this.proxy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JmTaskRow(')
          ..write('albumId: $albumId, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('phase: $phase, ')
          ..write('error: $error, ')
          ..write('pages: $pages, ')
          ..write('keptOriginal: $keptOriginal, ')
          ..write('ffmpegPath: $ffmpegPath, ')
          ..write('proxy: $proxy, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    albumId,
    title,
    status,
    phase,
    error,
    pages,
    keptOriginal,
    ffmpegPath,
    proxy,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JmTaskRow &&
          other.albumId == this.albumId &&
          other.title == this.title &&
          other.status == this.status &&
          other.phase == this.phase &&
          other.error == this.error &&
          other.pages == this.pages &&
          other.keptOriginal == this.keptOriginal &&
          other.ffmpegPath == this.ffmpegPath &&
          other.proxy == this.proxy &&
          other.updatedAt == this.updatedAt);
}

class JmTasksCompanion extends UpdateCompanion<JmTaskRow> {
  final Value<String> albumId;
  final Value<String> title;
  final Value<String> status;
  final Value<String> phase;
  final Value<String?> error;
  final Value<int?> pages;
  final Value<int?> keptOriginal;
  final Value<String> ffmpegPath;
  final Value<String> proxy;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const JmTasksCompanion({
    this.albumId = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.phase = const Value.absent(),
    this.error = const Value.absent(),
    this.pages = const Value.absent(),
    this.keptOriginal = const Value.absent(),
    this.ffmpegPath = const Value.absent(),
    this.proxy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JmTasksCompanion.insert({
    required String albumId,
    required String title,
    required String status,
    this.phase = const Value.absent(),
    this.error = const Value.absent(),
    this.pages = const Value.absent(),
    this.keptOriginal = const Value.absent(),
    this.ffmpegPath = const Value.absent(),
    this.proxy = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : albumId = Value(albumId),
       title = Value(title),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<JmTaskRow> custom({
    Expression<String>? albumId,
    Expression<String>? title,
    Expression<String>? status,
    Expression<String>? phase,
    Expression<String>? error,
    Expression<int>? pages,
    Expression<int>? keptOriginal,
    Expression<String>? ffmpegPath,
    Expression<String>? proxy,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (albumId != null) 'album_id': albumId,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (phase != null) 'phase': phase,
      if (error != null) 'error': error,
      if (pages != null) 'pages': pages,
      if (keptOriginal != null) 'kept_original': keptOriginal,
      if (ffmpegPath != null) 'ffmpeg_path': ffmpegPath,
      if (proxy != null) 'proxy': proxy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JmTasksCompanion copyWith({
    Value<String>? albumId,
    Value<String>? title,
    Value<String>? status,
    Value<String>? phase,
    Value<String?>? error,
    Value<int?>? pages,
    Value<int?>? keptOriginal,
    Value<String>? ffmpegPath,
    Value<String>? proxy,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return JmTasksCompanion(
      albumId: albumId ?? this.albumId,
      title: title ?? this.title,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      error: error ?? this.error,
      pages: pages ?? this.pages,
      keptOriginal: keptOriginal ?? this.keptOriginal,
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      proxy: proxy ?? this.proxy,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (pages.present) {
      map['pages'] = Variable<int>(pages.value);
    }
    if (keptOriginal.present) {
      map['kept_original'] = Variable<int>(keptOriginal.value);
    }
    if (ffmpegPath.present) {
      map['ffmpeg_path'] = Variable<String>(ffmpegPath.value);
    }
    if (proxy.present) {
      map['proxy'] = Variable<String>(proxy.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JmTasksCompanion(')
          ..write('albumId: $albumId, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('phase: $phase, ')
          ..write('error: $error, ')
          ..write('pages: $pages, ')
          ..write('keptOriginal: $keptOriginal, ')
          ..write('ffmpegPath: $ffmpegPath, ')
          ..write('proxy: $proxy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NovelSourcesTable extends NovelSources
    with TableInfo<$NovelSourcesTable, NovelSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NovelSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _disableReasonMeta = const VerificationMeta(
    'disableReason',
  );
  @override
  late final GeneratedColumn<String> disableReason = GeneratedColumn<String>(
    'disable_reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lastTestResultMeta = const VerificationMeta(
    'lastTestResult',
  );
  @override
  late final GeneratedColumn<String> lastTestResult = GeneratedColumn<String>(
    'last_test_result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lastTestedAtMeta = const VerificationMeta(
    'lastTestedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastTestedAt = GeneratedColumn<DateTime>(
    'last_tested_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    name,
    json,
    enabled,
    disableReason,
    lastTestResult,
    lastTestedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'novel_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<NovelSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('disable_reason')) {
      context.handle(
        _disableReasonMeta,
        disableReason.isAcceptableOrUnknown(
          data['disable_reason']!,
          _disableReasonMeta,
        ),
      );
    }
    if (data.containsKey('last_test_result')) {
      context.handle(
        _lastTestResultMeta,
        lastTestResult.isAcceptableOrUnknown(
          data['last_test_result']!,
          _lastTestResultMeta,
        ),
      );
    }
    if (data.containsKey('last_tested_at')) {
      context.handle(
        _lastTestedAtMeta,
        lastTestedAt.isAcceptableOrUnknown(
          data['last_tested_at']!,
          _lastTestedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId};
  @override
  NovelSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NovelSource(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      disableReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}disable_reason'],
      )!,
      lastTestResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_test_result'],
      )!,
      lastTestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_tested_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NovelSourcesTable createAlias(String alias) {
    return $NovelSourcesTable(attachedDatabase, alias);
  }
}

class NovelSource extends DataClass implements Insertable<NovelSource> {
  final String sourceId;
  final String name;
  final String json;
  final bool enabled;
  final String disableReason;
  final String lastTestResult;
  final DateTime? lastTestedAt;
  final DateTime updatedAt;
  const NovelSource({
    required this.sourceId,
    required this.name,
    required this.json,
    required this.enabled,
    required this.disableReason,
    required this.lastTestResult,
    this.lastTestedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['name'] = Variable<String>(name);
    map['json'] = Variable<String>(json);
    map['enabled'] = Variable<bool>(enabled);
    map['disable_reason'] = Variable<String>(disableReason);
    map['last_test_result'] = Variable<String>(lastTestResult);
    if (!nullToAbsent || lastTestedAt != null) {
      map['last_tested_at'] = Variable<DateTime>(lastTestedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NovelSourcesCompanion toCompanion(bool nullToAbsent) {
    return NovelSourcesCompanion(
      sourceId: Value(sourceId),
      name: Value(name),
      json: Value(json),
      enabled: Value(enabled),
      disableReason: Value(disableReason),
      lastTestResult: Value(lastTestResult),
      lastTestedAt: lastTestedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTestedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NovelSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NovelSource(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      name: serializer.fromJson<String>(json['name']),
      json: serializer.fromJson<String>(json['json']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      disableReason: serializer.fromJson<String>(json['disableReason']),
      lastTestResult: serializer.fromJson<String>(json['lastTestResult']),
      lastTestedAt: serializer.fromJson<DateTime?>(json['lastTestedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'name': serializer.toJson<String>(name),
      'json': serializer.toJson<String>(json),
      'enabled': serializer.toJson<bool>(enabled),
      'disableReason': serializer.toJson<String>(disableReason),
      'lastTestResult': serializer.toJson<String>(lastTestResult),
      'lastTestedAt': serializer.toJson<DateTime?>(lastTestedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NovelSource copyWith({
    String? sourceId,
    String? name,
    String? json,
    bool? enabled,
    String? disableReason,
    String? lastTestResult,
    Value<DateTime?> lastTestedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => NovelSource(
    sourceId: sourceId ?? this.sourceId,
    name: name ?? this.name,
    json: json ?? this.json,
    enabled: enabled ?? this.enabled,
    disableReason: disableReason ?? this.disableReason,
    lastTestResult: lastTestResult ?? this.lastTestResult,
    lastTestedAt: lastTestedAt.present ? lastTestedAt.value : this.lastTestedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NovelSource copyWithCompanion(NovelSourcesCompanion data) {
    return NovelSource(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      name: data.name.present ? data.name.value : this.name,
      json: data.json.present ? data.json.value : this.json,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      disableReason: data.disableReason.present
          ? data.disableReason.value
          : this.disableReason,
      lastTestResult: data.lastTestResult.present
          ? data.lastTestResult.value
          : this.lastTestResult,
      lastTestedAt: data.lastTestedAt.present
          ? data.lastTestedAt.value
          : this.lastTestedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NovelSource(')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('json: $json, ')
          ..write('enabled: $enabled, ')
          ..write('disableReason: $disableReason, ')
          ..write('lastTestResult: $lastTestResult, ')
          ..write('lastTestedAt: $lastTestedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    name,
    json,
    enabled,
    disableReason,
    lastTestResult,
    lastTestedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NovelSource &&
          other.sourceId == this.sourceId &&
          other.name == this.name &&
          other.json == this.json &&
          other.enabled == this.enabled &&
          other.disableReason == this.disableReason &&
          other.lastTestResult == this.lastTestResult &&
          other.lastTestedAt == this.lastTestedAt &&
          other.updatedAt == this.updatedAt);
}

class NovelSourcesCompanion extends UpdateCompanion<NovelSource> {
  final Value<String> sourceId;
  final Value<String> name;
  final Value<String> json;
  final Value<bool> enabled;
  final Value<String> disableReason;
  final Value<String> lastTestResult;
  final Value<DateTime?> lastTestedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NovelSourcesCompanion({
    this.sourceId = const Value.absent(),
    this.name = const Value.absent(),
    this.json = const Value.absent(),
    this.enabled = const Value.absent(),
    this.disableReason = const Value.absent(),
    this.lastTestResult = const Value.absent(),
    this.lastTestedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NovelSourcesCompanion.insert({
    required String sourceId,
    required String name,
    this.json = const Value.absent(),
    this.enabled = const Value.absent(),
    this.disableReason = const Value.absent(),
    this.lastTestResult = const Value.absent(),
    this.lastTestedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<NovelSource> custom({
    Expression<String>? sourceId,
    Expression<String>? name,
    Expression<String>? json,
    Expression<bool>? enabled,
    Expression<String>? disableReason,
    Expression<String>? lastTestResult,
    Expression<DateTime>? lastTestedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (name != null) 'name': name,
      if (json != null) 'json': json,
      if (enabled != null) 'enabled': enabled,
      if (disableReason != null) 'disable_reason': disableReason,
      if (lastTestResult != null) 'last_test_result': lastTestResult,
      if (lastTestedAt != null) 'last_tested_at': lastTestedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NovelSourcesCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? name,
    Value<String>? json,
    Value<bool>? enabled,
    Value<String>? disableReason,
    Value<String>? lastTestResult,
    Value<DateTime?>? lastTestedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NovelSourcesCompanion(
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      json: json ?? this.json,
      enabled: enabled ?? this.enabled,
      disableReason: disableReason ?? this.disableReason,
      lastTestResult: lastTestResult ?? this.lastTestResult,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (disableReason.present) {
      map['disable_reason'] = Variable<String>(disableReason.value);
    }
    if (lastTestResult.present) {
      map['last_test_result'] = Variable<String>(lastTestResult.value);
    }
    if (lastTestedAt.present) {
      map['last_tested_at'] = Variable<DateTime>(lastTestedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NovelSourcesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('json: $json, ')
          ..write('enabled: $enabled, ')
          ..write('disableReason: $disableReason, ')
          ..write('lastTestResult: $lastTestResult, ')
          ..write('lastTestedAt: $lastTestedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NovelTasksTable extends NovelTasks
    with TableInfo<$NovelTasksTable, NovelTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NovelTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workIdMeta = const VerificationMeta('workId');
  @override
  late final GeneratedColumn<String> workId = GeneratedColumn<String>(
    'work_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failedChaptersMeta = const VerificationMeta(
    'failedChapters',
  );
  @override
  late final GeneratedColumn<String> failedChapters = GeneratedColumn<String>(
    'failed_chapters',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _totalChaptersMeta = const VerificationMeta(
    'totalChapters',
  );
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
    'total_chapters',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneChaptersMeta = const VerificationMeta(
    'doneChapters',
  );
  @override
  late final GeneratedColumn<int> doneChapters = GeneratedColumn<int>(
    'done_chapters',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<String> snapshot = GeneratedColumn<String>(
    'snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    workId,
    title,
    status,
    phase,
    error,
    failedChapters,
    totalChapters,
    doneChapters,
    snapshot,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'novel_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<NovelTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('work_id')) {
      context.handle(
        _workIdMeta,
        workId.isAcceptableOrUnknown(data['work_id']!, _workIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('failed_chapters')) {
      context.handle(
        _failedChaptersMeta,
        failedChapters.isAcceptableOrUnknown(
          data['failed_chapters']!,
          _failedChaptersMeta,
        ),
      );
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
        _totalChaptersMeta,
        totalChapters.isAcceptableOrUnknown(
          data['total_chapters']!,
          _totalChaptersMeta,
        ),
      );
    }
    if (data.containsKey('done_chapters')) {
      context.handle(
        _doneChaptersMeta,
        doneChapters.isAcceptableOrUnknown(
          data['done_chapters']!,
          _doneChaptersMeta,
        ),
      );
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workId};
  @override
  NovelTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NovelTaskRow(
      workId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      failedChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failed_chapters'],
      )!,
      totalChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapters'],
      ),
      doneChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_chapters'],
      ),
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NovelTasksTable createAlias(String alias) {
    return $NovelTasksTable(attachedDatabase, alias);
  }
}

class NovelTaskRow extends DataClass implements Insertable<NovelTaskRow> {
  final String workId;
  final String title;
  final String status;
  final String phase;
  final String? error;

  /// 缺章清单摘要（终态 failed 时）："3,17,42" 或空。
  final String failedChapters;
  final int? totalChapters;
  final int? doneChapters;

  /// 启动配置快照（恢复续跑/重试的完整输入，JSON）。
  final String snapshot;
  final DateTime updatedAt;
  const NovelTaskRow({
    required this.workId,
    required this.title,
    required this.status,
    required this.phase,
    this.error,
    required this.failedChapters,
    this.totalChapters,
    this.doneChapters,
    required this.snapshot,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['work_id'] = Variable<String>(workId);
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    map['phase'] = Variable<String>(phase);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['failed_chapters'] = Variable<String>(failedChapters);
    if (!nullToAbsent || totalChapters != null) {
      map['total_chapters'] = Variable<int>(totalChapters);
    }
    if (!nullToAbsent || doneChapters != null) {
      map['done_chapters'] = Variable<int>(doneChapters);
    }
    map['snapshot'] = Variable<String>(snapshot);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NovelTasksCompanion toCompanion(bool nullToAbsent) {
    return NovelTasksCompanion(
      workId: Value(workId),
      title: Value(title),
      status: Value(status),
      phase: Value(phase),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      failedChapters: Value(failedChapters),
      totalChapters: totalChapters == null && nullToAbsent
          ? const Value.absent()
          : Value(totalChapters),
      doneChapters: doneChapters == null && nullToAbsent
          ? const Value.absent()
          : Value(doneChapters),
      snapshot: Value(snapshot),
      updatedAt: Value(updatedAt),
    );
  }

  factory NovelTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NovelTaskRow(
      workId: serializer.fromJson<String>(json['workId']),
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      phase: serializer.fromJson<String>(json['phase']),
      error: serializer.fromJson<String?>(json['error']),
      failedChapters: serializer.fromJson<String>(json['failedChapters']),
      totalChapters: serializer.fromJson<int?>(json['totalChapters']),
      doneChapters: serializer.fromJson<int?>(json['doneChapters']),
      snapshot: serializer.fromJson<String>(json['snapshot']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workId': serializer.toJson<String>(workId),
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'phase': serializer.toJson<String>(phase),
      'error': serializer.toJson<String?>(error),
      'failedChapters': serializer.toJson<String>(failedChapters),
      'totalChapters': serializer.toJson<int?>(totalChapters),
      'doneChapters': serializer.toJson<int?>(doneChapters),
      'snapshot': serializer.toJson<String>(snapshot),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NovelTaskRow copyWith({
    String? workId,
    String? title,
    String? status,
    String? phase,
    Value<String?> error = const Value.absent(),
    String? failedChapters,
    Value<int?> totalChapters = const Value.absent(),
    Value<int?> doneChapters = const Value.absent(),
    String? snapshot,
    DateTime? updatedAt,
  }) => NovelTaskRow(
    workId: workId ?? this.workId,
    title: title ?? this.title,
    status: status ?? this.status,
    phase: phase ?? this.phase,
    error: error.present ? error.value : this.error,
    failedChapters: failedChapters ?? this.failedChapters,
    totalChapters: totalChapters.present
        ? totalChapters.value
        : this.totalChapters,
    doneChapters: doneChapters.present ? doneChapters.value : this.doneChapters,
    snapshot: snapshot ?? this.snapshot,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NovelTaskRow copyWithCompanion(NovelTasksCompanion data) {
    return NovelTaskRow(
      workId: data.workId.present ? data.workId.value : this.workId,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      phase: data.phase.present ? data.phase.value : this.phase,
      error: data.error.present ? data.error.value : this.error,
      failedChapters: data.failedChapters.present
          ? data.failedChapters.value
          : this.failedChapters,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      doneChapters: data.doneChapters.present
          ? data.doneChapters.value
          : this.doneChapters,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NovelTaskRow(')
          ..write('workId: $workId, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('phase: $phase, ')
          ..write('error: $error, ')
          ..write('failedChapters: $failedChapters, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('doneChapters: $doneChapters, ')
          ..write('snapshot: $snapshot, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    workId,
    title,
    status,
    phase,
    error,
    failedChapters,
    totalChapters,
    doneChapters,
    snapshot,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NovelTaskRow &&
          other.workId == this.workId &&
          other.title == this.title &&
          other.status == this.status &&
          other.phase == this.phase &&
          other.error == this.error &&
          other.failedChapters == this.failedChapters &&
          other.totalChapters == this.totalChapters &&
          other.doneChapters == this.doneChapters &&
          other.snapshot == this.snapshot &&
          other.updatedAt == this.updatedAt);
}

class NovelTasksCompanion extends UpdateCompanion<NovelTaskRow> {
  final Value<String> workId;
  final Value<String> title;
  final Value<String> status;
  final Value<String> phase;
  final Value<String?> error;
  final Value<String> failedChapters;
  final Value<int?> totalChapters;
  final Value<int?> doneChapters;
  final Value<String> snapshot;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NovelTasksCompanion({
    this.workId = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.phase = const Value.absent(),
    this.error = const Value.absent(),
    this.failedChapters = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.doneChapters = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NovelTasksCompanion.insert({
    required String workId,
    required String title,
    required String status,
    this.phase = const Value.absent(),
    this.error = const Value.absent(),
    this.failedChapters = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.doneChapters = const Value.absent(),
    this.snapshot = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : workId = Value(workId),
       title = Value(title),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<NovelTaskRow> custom({
    Expression<String>? workId,
    Expression<String>? title,
    Expression<String>? status,
    Expression<String>? phase,
    Expression<String>? error,
    Expression<String>? failedChapters,
    Expression<int>? totalChapters,
    Expression<int>? doneChapters,
    Expression<String>? snapshot,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workId != null) 'work_id': workId,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (phase != null) 'phase': phase,
      if (error != null) 'error': error,
      if (failedChapters != null) 'failed_chapters': failedChapters,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (doneChapters != null) 'done_chapters': doneChapters,
      if (snapshot != null) 'snapshot': snapshot,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NovelTasksCompanion copyWith({
    Value<String>? workId,
    Value<String>? title,
    Value<String>? status,
    Value<String>? phase,
    Value<String?>? error,
    Value<String>? failedChapters,
    Value<int?>? totalChapters,
    Value<int?>? doneChapters,
    Value<String>? snapshot,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NovelTasksCompanion(
      workId: workId ?? this.workId,
      title: title ?? this.title,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      error: error ?? this.error,
      failedChapters: failedChapters ?? this.failedChapters,
      totalChapters: totalChapters ?? this.totalChapters,
      doneChapters: doneChapters ?? this.doneChapters,
      snapshot: snapshot ?? this.snapshot,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workId.present) {
      map['work_id'] = Variable<String>(workId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (failedChapters.present) {
      map['failed_chapters'] = Variable<String>(failedChapters.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (doneChapters.present) {
      map['done_chapters'] = Variable<int>(doneChapters.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<String>(snapshot.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NovelTasksCompanion(')
          ..write('workId: $workId, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('phase: $phase, ')
          ..write('error: $error, ')
          ..write('failedChapters: $failedChapters, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('doneChapters: $doneChapters, ')
          ..write('snapshot: $snapshot, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MangaCollectionsTable extends MangaCollections
    with TableInfo<$MangaCollectionsTable, MangaCollection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaCollection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MangaCollection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaCollection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MangaCollectionsTable createAlias(String alias) {
    return $MangaCollectionsTable(attachedDatabase, alias);
  }
}

class MangaCollection extends DataClass implements Insertable<MangaCollection> {
  final int id;
  final String name;
  final DateTime createdAt;
  const MangaCollection({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MangaCollectionsCompanion toCompanion(bool nullToAbsent) {
    return MangaCollectionsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory MangaCollection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaCollection(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MangaCollection copyWith({int? id, String? name, DateTime? createdAt}) =>
      MangaCollection(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  MangaCollection copyWithCompanion(MangaCollectionsCompanion data) {
    return MangaCollection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaCollection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaCollection &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class MangaCollectionsCompanion extends UpdateCompanion<MangaCollection> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const MangaCollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MangaCollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<MangaCollection> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MangaCollectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return MangaCollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MangaCollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MangaCollectionEntriesTable extends MangaCollectionEntries
    with TableInfo<$MangaCollectionEntriesTable, MangaCollectionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaCollectionEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workIdMeta = const VerificationMeta('workId');
  @override
  late final GeneratedColumn<String> workId = GeneratedColumn<String>(
    'work_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [collectionId, workId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_collection_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaCollectionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('work_id')) {
      context.handle(
        _workIdMeta,
        workId.isAcceptableOrUnknown(data['work_id']!, _workIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, workId};
  @override
  MangaCollectionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaCollectionEntry(
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      )!,
      workId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_id'],
      )!,
    );
  }

  @override
  $MangaCollectionEntriesTable createAlias(String alias) {
    return $MangaCollectionEntriesTable(attachedDatabase, alias);
  }
}

class MangaCollectionEntry extends DataClass
    implements Insertable<MangaCollectionEntry> {
  final int collectionId;
  final String workId;
  const MangaCollectionEntry({
    required this.collectionId,
    required this.workId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<int>(collectionId);
    map['work_id'] = Variable<String>(workId);
    return map;
  }

  MangaCollectionEntriesCompanion toCompanion(bool nullToAbsent) {
    return MangaCollectionEntriesCompanion(
      collectionId: Value(collectionId),
      workId: Value(workId),
    );
  }

  factory MangaCollectionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaCollectionEntry(
      collectionId: serializer.fromJson<int>(json['collectionId']),
      workId: serializer.fromJson<String>(json['workId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<int>(collectionId),
      'workId': serializer.toJson<String>(workId),
    };
  }

  MangaCollectionEntry copyWith({int? collectionId, String? workId}) =>
      MangaCollectionEntry(
        collectionId: collectionId ?? this.collectionId,
        workId: workId ?? this.workId,
      );
  MangaCollectionEntry copyWithCompanion(MangaCollectionEntriesCompanion data) {
    return MangaCollectionEntry(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      workId: data.workId.present ? data.workId.value : this.workId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaCollectionEntry(')
          ..write('collectionId: $collectionId, ')
          ..write('workId: $workId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, workId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaCollectionEntry &&
          other.collectionId == this.collectionId &&
          other.workId == this.workId);
}

class MangaCollectionEntriesCompanion
    extends UpdateCompanion<MangaCollectionEntry> {
  final Value<int> collectionId;
  final Value<String> workId;
  final Value<int> rowid;
  const MangaCollectionEntriesCompanion({
    this.collectionId = const Value.absent(),
    this.workId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MangaCollectionEntriesCompanion.insert({
    required int collectionId,
    required String workId,
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       workId = Value(workId);
  static Insertable<MangaCollectionEntry> custom({
    Expression<int>? collectionId,
    Expression<String>? workId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (workId != null) 'work_id': workId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MangaCollectionEntriesCompanion copyWith({
    Value<int>? collectionId,
    Value<String>? workId,
    Value<int>? rowid,
  }) {
    return MangaCollectionEntriesCompanion(
      collectionId: collectionId ?? this.collectionId,
      workId: workId ?? this.workId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (workId.present) {
      map['work_id'] = Variable<String>(workId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MangaCollectionEntriesCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('workId: $workId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WorksTable works = $WorksTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $JmTasksTable jmTasks = $JmTasksTable(this);
  late final $NovelSourcesTable novelSources = $NovelSourcesTable(this);
  late final $NovelTasksTable novelTasks = $NovelTasksTable(this);
  late final $MangaCollectionsTable mangaCollections = $MangaCollectionsTable(
    this,
  );
  late final $MangaCollectionEntriesTable mangaCollectionEntries =
      $MangaCollectionEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    works,
    bookmarks,
    readingProgress,
    settings,
    syncState,
    jmTasks,
    novelSources,
    novelTasks,
    mangaCollections,
    mangaCollectionEntries,
  ];
}

typedef $$WorksTableCreateCompanionBuilder = WorksCompanion Function({
  required String id,
  required String type,
  required String title,
  Value<String> titleJp,
  Value<String> author,
  Value<String> series,
  Value<int?> volume,
  Value<String> tags,
  Value<String> status,
  Value<int?> totalChars,
  Value<int?> pages,
  Value<String?> lastUpdated,
  Value<String?> cover,
  Value<String> origin,
  Value<bool> localOnly,
  Value<bool> hasZh,
  Value<String> zhQuality,
  Value<String?> publishedAt,
  Value<String?> completedAt,
  Value<String?> etag,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});
typedef $$WorksTableUpdateCompanionBuilder = WorksCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> title,
  Value<String> titleJp,
  Value<String> author,
  Value<String> series,
  Value<int?> volume,
  Value<String> tags,
  Value<String> status,
  Value<int?> totalChars,
  Value<int?> pages,
  Value<String?> lastUpdated,
  Value<String?> cover,
  Value<String> origin,
  Value<bool> localOnly,
  Value<bool> hasZh,
  Value<String> zhQuality,
  Value<String?> publishedAt,
  Value<String?> completedAt,
  Value<String?> etag,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});

class $$WorksTableFilterComposer extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleJp => $composableBuilder(
    column: $table.titleJp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChars => $composableBuilder(
    column: $table.totalChars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localOnly => $composableBuilder(
    column: $table.localOnly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasZh => $composableBuilder(
    column: $table.hasZh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zhQuality => $composableBuilder(
    column: $table.zhQuality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorksTableOrderingComposer
    extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleJp => $composableBuilder(
    column: $table.titleJp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChars => $composableBuilder(
    column: $table.totalChars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localOnly => $composableBuilder(
    column: $table.localOnly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasZh => $composableBuilder(
    column: $table.hasZh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zhQuality => $composableBuilder(
    column: $table.zhQuality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleJp =>
      $composableBuilder(column: $table.titleJp, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get series =>
      $composableBuilder(column: $table.series, builder: (column) => column);

  GeneratedColumn<int> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get totalChars => $composableBuilder(
    column: $table.totalChars,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pages =>
      $composableBuilder(column: $table.pages, builder: (column) => column);

  GeneratedColumn<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<bool> get localOnly =>
      $composableBuilder(column: $table.localOnly, builder: (column) => column);

  GeneratedColumn<bool> get hasZh =>
      $composableBuilder(column: $table.hasZh, builder: (column) => column);

  GeneratedColumn<String> get zhQuality =>
      $composableBuilder(column: $table.zhQuality, builder: (column) => column);

  GeneratedColumn<String> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$WorksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorksTable,
          Work,
          $$WorksTableFilterComposer,
          $$WorksTableOrderingComposer,
          $$WorksTableAnnotationComposer,
          $$WorksTableCreateCompanionBuilder,
          $$WorksTableUpdateCompanionBuilder,
          (Work, BaseReferences<_$AppDatabase, $WorksTable, Work>),
          Work,
          PrefetchHooks Function()
        > {
  $$WorksTableTableManager(_$AppDatabase db, $WorksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> titleJp = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> series = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> totalChars = const Value.absent(),
                Value<int?> pages = const Value.absent(),
                Value<String?> lastUpdated = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<bool> localOnly = const Value.absent(),
                Value<bool> hasZh = const Value.absent(),
                Value<String> zhQuality = const Value.absent(),
                Value<String?> publishedAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorksCompanion(
                id: id,
                type: type,
                title: title,
                titleJp: titleJp,
                author: author,
                series: series,
                volume: volume,
                tags: tags,
                status: status,
                totalChars: totalChars,
                pages: pages,
                lastUpdated: lastUpdated,
                cover: cover,
                origin: origin,
                localOnly: localOnly,
                hasZh: hasZh,
                zhQuality: zhQuality,
                publishedAt: publishedAt,
                completedAt: completedAt,
                etag: etag,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String title,
                Value<String> titleJp = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> series = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> totalChars = const Value.absent(),
                Value<int?> pages = const Value.absent(),
                Value<String?> lastUpdated = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<bool> localOnly = const Value.absent(),
                Value<bool> hasZh = const Value.absent(),
                Value<String> zhQuality = const Value.absent(),
                Value<String?> publishedAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorksCompanion.insert(
                id: id,
                type: type,
                title: title,
                titleJp: titleJp,
                author: author,
                series: series,
                volume: volume,
                tags: tags,
                status: status,
                totalChars: totalChars,
                pages: pages,
                lastUpdated: lastUpdated,
                cover: cover,
                origin: origin,
                localOnly: localOnly,
                hasZh: hasZh,
                zhQuality: zhQuality,
                publishedAt: publishedAt,
                completedAt: completedAt,
                etag: etag,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorksTable, Work>(table),
                  BaseReferences<_$AppDatabase, $WorksTable, Work>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorksTable,
      Work,
      $$WorksTableFilterComposer,
      $$WorksTableOrderingComposer,
      $$WorksTableAnnotationComposer,
      $$WorksTableCreateCompanionBuilder,
      $$WorksTableUpdateCompanionBuilder,
      (Work, BaseReferences<_$AppDatabase, $WorksTable, Work>),
      Work,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  required String id,
  required String workId,
  required String loc,
  Value<String> note,
  Value<String> color,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<String> id,
  Value<String> workId,
  Value<String> loc,
  Value<String> note,
  Value<String> color,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loc => $composableBuilder(
    column: $table.loc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loc => $composableBuilder(
    column: $table.loc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workId =>
      $composableBuilder(column: $table.workId, builder: (column) => column);

  GeneratedColumn<String> get loc =>
      $composableBuilder(column: $table.loc, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workId = const Value.absent(),
                Value<String> loc = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                workId: workId,
                loc: loc,
                note: note,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workId,
                required String loc,
                Value<String> note = const Value.absent(),
                Value<String> color = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                workId: workId,
                loc: loc,
                note: note,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, Bookmark>(table),
                  BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      required String workId,
      required String loc,
      Value<String> dev,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<String> workId,
      Value<String> loc,
      Value<String> dev,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ReadingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loc => $composableBuilder(
    column: $table.loc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dev => $composableBuilder(
    column: $table.dev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loc => $composableBuilder(
    column: $table.loc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dev => $composableBuilder(
    column: $table.dev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get workId =>
      $composableBuilder(column: $table.workId, builder: (column) => column);

  GeneratedColumn<String> get loc =>
      $composableBuilder(column: $table.loc, builder: (column) => column);

  GeneratedColumn<String> get dev =>
      $composableBuilder(column: $table.dev, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (
            ReadingProgressData,
            BaseReferences<
              _$AppDatabase,
              $ReadingProgressTable,
              ReadingProgressData
            >,
          ),
          ReadingProgressData,
          PrefetchHooks Function()
        > {
  $$ReadingProgressTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> workId = const Value.absent(),
                Value<String> loc = const Value.absent(),
                Value<String> dev = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion(
                workId: workId,
                loc: loc,
                dev: dev,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String workId,
                required String loc,
                Value<String> dev = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                workId: workId,
                loc: loc,
                dev: dev,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingProgressTable, ReadingProgressData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ReadingProgressTable,
                    ReadingProgressData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTable,
      ReadingProgressData,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (
        ReadingProgressData,
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData
        >,
      ),
      ReadingProgressData,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<String> scope,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<String> scope,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                value: value,
                scope: scope,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<String> scope = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                scope: scope,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String name,
  Value<int> byteOffset,
  Value<int> lineCount,
  Value<String?> etag,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> name,
  Value<int> byteOffset,
  Value<int> lineCount,
  Value<String?> etag,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteOffset => $composableBuilder(
    column: $table.byteOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteOffset => $composableBuilder(
    column: $table.byteOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get byteOffset => $composableBuilder(
    column: $table.byteOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lineCount =>
      $composableBuilder(column: $table.lineCount, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<int> byteOffset = const Value.absent(),
                Value<int> lineCount = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                name: name,
                byteOffset: byteOffset,
                lineCount: lineCount,
                etag: etag,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                Value<int> byteOffset = const Value.absent(),
                Value<int> lineCount = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                name: name,
                byteOffset: byteOffset,
                lineCount: lineCount,
                etag: etag,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateData>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$JmTasksTableCreateCompanionBuilder = JmTasksCompanion Function({
  required String albumId,
  required String title,
  required String status,
  Value<String> phase,
  Value<String?> error,
  Value<int?> pages,
  Value<int?> keptOriginal,
  Value<String> ffmpegPath,
  Value<String> proxy,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$JmTasksTableUpdateCompanionBuilder = JmTasksCompanion Function({
  Value<String> albumId,
  Value<String> title,
  Value<String> status,
  Value<String> phase,
  Value<String?> error,
  Value<int?> pages,
  Value<int?> keptOriginal,
  Value<String> ffmpegPath,
  Value<String> proxy,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$JmTasksTableFilterComposer
    extends Composer<_$AppDatabase, $JmTasksTable> {
  $$JmTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get keptOriginal => $composableBuilder(
    column: $table.keptOriginal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ffmpegPath => $composableBuilder(
    column: $table.ffmpegPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxy => $composableBuilder(
    column: $table.proxy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JmTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $JmTasksTable> {
  $$JmTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get keptOriginal => $composableBuilder(
    column: $table.keptOriginal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ffmpegPath => $composableBuilder(
    column: $table.ffmpegPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxy => $composableBuilder(
    column: $table.proxy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JmTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $JmTasksTable> {
  $$JmTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get pages =>
      $composableBuilder(column: $table.pages, builder: (column) => column);

  GeneratedColumn<int> get keptOriginal => $composableBuilder(
    column: $table.keptOriginal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ffmpegPath => $composableBuilder(
    column: $table.ffmpegPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proxy =>
      $composableBuilder(column: $table.proxy, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$JmTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JmTasksTable,
          JmTaskRow,
          $$JmTasksTableFilterComposer,
          $$JmTasksTableOrderingComposer,
          $$JmTasksTableAnnotationComposer,
          $$JmTasksTableCreateCompanionBuilder,
          $$JmTasksTableUpdateCompanionBuilder,
          (JmTaskRow, BaseReferences<_$AppDatabase, $JmTasksTable, JmTaskRow>),
          JmTaskRow,
          PrefetchHooks Function()
        > {
  $$JmTasksTableTableManager(_$AppDatabase db, $JmTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JmTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JmTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JmTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> albumId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int?> pages = const Value.absent(),
                Value<int?> keptOriginal = const Value.absent(),
                Value<String> ffmpegPath = const Value.absent(),
                Value<String> proxy = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JmTasksCompanion(
                albumId: albumId,
                title: title,
                status: status,
                phase: phase,
                error: error,
                pages: pages,
                keptOriginal: keptOriginal,
                ffmpegPath: ffmpegPath,
                proxy: proxy,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String albumId,
                required String title,
                required String status,
                Value<String> phase = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int?> pages = const Value.absent(),
                Value<int?> keptOriginal = const Value.absent(),
                Value<String> ffmpegPath = const Value.absent(),
                Value<String> proxy = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => JmTasksCompanion.insert(
                albumId: albumId,
                title: title,
                status: status,
                phase: phase,
                error: error,
                pages: pages,
                keptOriginal: keptOriginal,
                ffmpegPath: ffmpegPath,
                proxy: proxy,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JmTasksTable, JmTaskRow>(table),
                  BaseReferences<_$AppDatabase, $JmTasksTable, JmTaskRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JmTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JmTasksTable,
      JmTaskRow,
      $$JmTasksTableFilterComposer,
      $$JmTasksTableOrderingComposer,
      $$JmTasksTableAnnotationComposer,
      $$JmTasksTableCreateCompanionBuilder,
      $$JmTasksTableUpdateCompanionBuilder,
      (JmTaskRow, BaseReferences<_$AppDatabase, $JmTasksTable, JmTaskRow>),
      JmTaskRow,
      PrefetchHooks Function()
    >;
typedef $$NovelSourcesTableCreateCompanionBuilder =
    NovelSourcesCompanion Function({
      required String sourceId,
      required String name,
      Value<String> json,
      Value<bool> enabled,
      Value<String> disableReason,
      Value<String> lastTestResult,
      Value<DateTime?> lastTestedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NovelSourcesTableUpdateCompanionBuilder =
    NovelSourcesCompanion Function({
      Value<String> sourceId,
      Value<String> name,
      Value<String> json,
      Value<bool> enabled,
      Value<String> disableReason,
      Value<String> lastTestResult,
      Value<DateTime?> lastTestedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$NovelSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $NovelSourcesTable> {
  $$NovelSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get disableReason => $composableBuilder(
    column: $table.disableReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastTestResult => $composableBuilder(
    column: $table.lastTestResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastTestedAt => $composableBuilder(
    column: $table.lastTestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NovelSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $NovelSourcesTable> {
  $$NovelSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get disableReason => $composableBuilder(
    column: $table.disableReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastTestResult => $composableBuilder(
    column: $table.lastTestResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastTestedAt => $composableBuilder(
    column: $table.lastTestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NovelSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NovelSourcesTable> {
  $$NovelSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get disableReason => $composableBuilder(
    column: $table.disableReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastTestResult => $composableBuilder(
    column: $table.lastTestResult,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastTestedAt => $composableBuilder(
    column: $table.lastTestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NovelSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NovelSourcesTable,
          NovelSource,
          $$NovelSourcesTableFilterComposer,
          $$NovelSourcesTableOrderingComposer,
          $$NovelSourcesTableAnnotationComposer,
          $$NovelSourcesTableCreateCompanionBuilder,
          $$NovelSourcesTableUpdateCompanionBuilder,
          (
            NovelSource,
            BaseReferences<_$AppDatabase, $NovelSourcesTable, NovelSource>,
          ),
          NovelSource,
          PrefetchHooks Function()
        > {
  $$NovelSourcesTableTableManager(_$AppDatabase db, $NovelSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NovelSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NovelSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NovelSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> disableReason = const Value.absent(),
                Value<String> lastTestResult = const Value.absent(),
                Value<DateTime?> lastTestedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NovelSourcesCompanion(
                sourceId: sourceId,
                name: name,
                json: json,
                enabled: enabled,
                disableReason: disableReason,
                lastTestResult: lastTestResult,
                lastTestedAt: lastTestedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String name,
                Value<String> json = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> disableReason = const Value.absent(),
                Value<String> lastTestResult = const Value.absent(),
                Value<DateTime?> lastTestedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NovelSourcesCompanion.insert(
                sourceId: sourceId,
                name: name,
                json: json,
                enabled: enabled,
                disableReason: disableReason,
                lastTestResult: lastTestResult,
                lastTestedAt: lastTestedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NovelSourcesTable, NovelSource>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $NovelSourcesTable,
                    NovelSource
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NovelSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NovelSourcesTable,
      NovelSource,
      $$NovelSourcesTableFilterComposer,
      $$NovelSourcesTableOrderingComposer,
      $$NovelSourcesTableAnnotationComposer,
      $$NovelSourcesTableCreateCompanionBuilder,
      $$NovelSourcesTableUpdateCompanionBuilder,
      (
        NovelSource,
        BaseReferences<_$AppDatabase, $NovelSourcesTable, NovelSource>,
      ),
      NovelSource,
      PrefetchHooks Function()
    >;
typedef $$NovelTasksTableCreateCompanionBuilder = NovelTasksCompanion Function({
  required String workId,
  required String title,
  required String status,
  Value<String> phase,
  Value<String?> error,
  Value<String> failedChapters,
  Value<int?> totalChapters,
  Value<int?> doneChapters,
  Value<String> snapshot,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$NovelTasksTableUpdateCompanionBuilder = NovelTasksCompanion Function({
  Value<String> workId,
  Value<String> title,
  Value<String> status,
  Value<String> phase,
  Value<String?> error,
  Value<String> failedChapters,
  Value<int?> totalChapters,
  Value<int?> doneChapters,
  Value<String> snapshot,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$NovelTasksTableFilterComposer
    extends Composer<_$AppDatabase, $NovelTasksTable> {
  $$NovelTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failedChapters => $composableBuilder(
    column: $table.failedChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneChapters => $composableBuilder(
    column: $table.doneChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NovelTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $NovelTasksTable> {
  $$NovelTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failedChapters => $composableBuilder(
    column: $table.failedChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneChapters => $composableBuilder(
    column: $table.doneChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NovelTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $NovelTasksTable> {
  $$NovelTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get workId =>
      $composableBuilder(column: $table.workId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get failedChapters => $composableBuilder(
    column: $table.failedChapters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get doneChapters => $composableBuilder(
    column: $table.doneChapters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NovelTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NovelTasksTable,
          NovelTaskRow,
          $$NovelTasksTableFilterComposer,
          $$NovelTasksTableOrderingComposer,
          $$NovelTasksTableAnnotationComposer,
          $$NovelTasksTableCreateCompanionBuilder,
          $$NovelTasksTableUpdateCompanionBuilder,
          (
            NovelTaskRow,
            BaseReferences<_$AppDatabase, $NovelTasksTable, NovelTaskRow>,
          ),
          NovelTaskRow,
          PrefetchHooks Function()
        > {
  $$NovelTasksTableTableManager(_$AppDatabase db, $NovelTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NovelTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NovelTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NovelTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> workId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String> failedChapters = const Value.absent(),
                Value<int?> totalChapters = const Value.absent(),
                Value<int?> doneChapters = const Value.absent(),
                Value<String> snapshot = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NovelTasksCompanion(
                workId: workId,
                title: title,
                status: status,
                phase: phase,
                error: error,
                failedChapters: failedChapters,
                totalChapters: totalChapters,
                doneChapters: doneChapters,
                snapshot: snapshot,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String workId,
                required String title,
                required String status,
                Value<String> phase = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String> failedChapters = const Value.absent(),
                Value<int?> totalChapters = const Value.absent(),
                Value<int?> doneChapters = const Value.absent(),
                Value<String> snapshot = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NovelTasksCompanion.insert(
                workId: workId,
                title: title,
                status: status,
                phase: phase,
                error: error,
                failedChapters: failedChapters,
                totalChapters: totalChapters,
                doneChapters: doneChapters,
                snapshot: snapshot,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NovelTasksTable, NovelTaskRow>(table),
                  BaseReferences<_$AppDatabase, $NovelTasksTable, NovelTaskRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NovelTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NovelTasksTable,
      NovelTaskRow,
      $$NovelTasksTableFilterComposer,
      $$NovelTasksTableOrderingComposer,
      $$NovelTasksTableAnnotationComposer,
      $$NovelTasksTableCreateCompanionBuilder,
      $$NovelTasksTableUpdateCompanionBuilder,
      (
        NovelTaskRow,
        BaseReferences<_$AppDatabase, $NovelTasksTable, NovelTaskRow>,
      ),
      NovelTaskRow,
      PrefetchHooks Function()
    >;
typedef $$MangaCollectionsTableCreateCompanionBuilder =
    MangaCollectionsCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
    });
typedef $$MangaCollectionsTableUpdateCompanionBuilder =
    MangaCollectionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

class $$MangaCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $MangaCollectionsTable> {
  $$MangaCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaCollectionsTable> {
  $$MangaCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaCollectionsTable> {
  $$MangaCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MangaCollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaCollectionsTable,
          MangaCollection,
          $$MangaCollectionsTableFilterComposer,
          $$MangaCollectionsTableOrderingComposer,
          $$MangaCollectionsTableAnnotationComposer,
          $$MangaCollectionsTableCreateCompanionBuilder,
          $$MangaCollectionsTableUpdateCompanionBuilder,
          (
            MangaCollection,
            BaseReferences<
              _$AppDatabase,
              $MangaCollectionsTable,
              MangaCollection
            >,
          ),
          MangaCollection,
          PrefetchHooks Function()
        > {
  $$MangaCollectionsTableTableManager(
    _$AppDatabase db,
    $MangaCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangaCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangaCollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MangaCollectionsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
              }) => MangaCollectionsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MangaCollectionsTable, MangaCollection>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MangaCollectionsTable,
                    MangaCollection
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MangaCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaCollectionsTable,
      MangaCollection,
      $$MangaCollectionsTableFilterComposer,
      $$MangaCollectionsTableOrderingComposer,
      $$MangaCollectionsTableAnnotationComposer,
      $$MangaCollectionsTableCreateCompanionBuilder,
      $$MangaCollectionsTableUpdateCompanionBuilder,
      (
        MangaCollection,
        BaseReferences<_$AppDatabase, $MangaCollectionsTable, MangaCollection>,
      ),
      MangaCollection,
      PrefetchHooks Function()
    >;
typedef $$MangaCollectionEntriesTableCreateCompanionBuilder =
    MangaCollectionEntriesCompanion Function({
      required int collectionId,
      required String workId,
      Value<int> rowid,
    });
typedef $$MangaCollectionEntriesTableUpdateCompanionBuilder =
    MangaCollectionEntriesCompanion Function({
      Value<int> collectionId,
      Value<String> workId,
      Value<int> rowid,
    });

class $$MangaCollectionEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MangaCollectionEntriesTable> {
  $$MangaCollectionEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaCollectionEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaCollectionEntriesTable> {
  $$MangaCollectionEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaCollectionEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaCollectionEntriesTable> {
  $$MangaCollectionEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workId =>
      $composableBuilder(column: $table.workId, builder: (column) => column);
}

class $$MangaCollectionEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaCollectionEntriesTable,
          MangaCollectionEntry,
          $$MangaCollectionEntriesTableFilterComposer,
          $$MangaCollectionEntriesTableOrderingComposer,
          $$MangaCollectionEntriesTableAnnotationComposer,
          $$MangaCollectionEntriesTableCreateCompanionBuilder,
          $$MangaCollectionEntriesTableUpdateCompanionBuilder,
          (
            MangaCollectionEntry,
            BaseReferences<
              _$AppDatabase,
              $MangaCollectionEntriesTable,
              MangaCollectionEntry
            >,
          ),
          MangaCollectionEntry,
          PrefetchHooks Function()
        > {
  $$MangaCollectionEntriesTableTableManager(
    _$AppDatabase db,
    $MangaCollectionEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaCollectionEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MangaCollectionEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MangaCollectionEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> collectionId = const Value.absent(),
                Value<String> workId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MangaCollectionEntriesCompanion(
                collectionId: collectionId,
                workId: workId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int collectionId,
                required String workId,
                Value<int> rowid = const Value.absent(),
              }) => MangaCollectionEntriesCompanion.insert(
                collectionId: collectionId,
                workId: workId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MangaCollectionEntriesTable,
                    MangaCollectionEntry
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MangaCollectionEntriesTable,
                    MangaCollectionEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MangaCollectionEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaCollectionEntriesTable,
      MangaCollectionEntry,
      $$MangaCollectionEntriesTableFilterComposer,
      $$MangaCollectionEntriesTableOrderingComposer,
      $$MangaCollectionEntriesTableAnnotationComposer,
      $$MangaCollectionEntriesTableCreateCompanionBuilder,
      $$MangaCollectionEntriesTableUpdateCompanionBuilder,
      (
        MangaCollectionEntry,
        BaseReferences<
          _$AppDatabase,
          $MangaCollectionEntriesTable,
          MangaCollectionEntry
        >,
      ),
      MangaCollectionEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WorksTableTableManager get works =>
      $$WorksTableTableManager(_db, _db.works);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$JmTasksTableTableManager get jmTasks =>
      $$JmTasksTableTableManager(_db, _db.jmTasks);
  $$NovelSourcesTableTableManager get novelSources =>
      $$NovelSourcesTableTableManager(_db, _db.novelSources);
  $$NovelTasksTableTableManager get novelTasks =>
      $$NovelTasksTableTableManager(_db, _db.novelTasks);
  $$MangaCollectionsTableTableManager get mangaCollections =>
      $$MangaCollectionsTableTableManager(_db, _db.mangaCollections);
  $$MangaCollectionEntriesTableTableManager get mangaCollectionEntries =>
      $$MangaCollectionEntriesTableTableManager(
        _db,
        _db.mangaCollectionEntries,
      );
}

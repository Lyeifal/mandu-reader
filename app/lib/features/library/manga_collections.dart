import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../providers.dart';
import 'shelf_query.dart';

class MangaCollectionSummary {
  const MangaCollectionSummary({
    required this.id,
    required this.name,
    required this.count,
  });

  final int id;
  final String name;
  final int count;
}

class MangaCollectionsRepository {
  MangaCollectionsRepository(this.db);

  final AppDatabase db;

  String _name(String raw) {
    final name = raw.trim();
    if (name.isEmpty) throw ArgumentError('收藏夹名称不能为空');
    return name;
  }

  Future<int> create(String name) async {
    final normalized = _name(name);
    final duplicate = await (db.select(
      db.mangaCollections,
    )..where((t) => t.name.equals(normalized))).getSingleOrNull();
    if (duplicate != null) throw StateError('收藏夹名称已存在');
    try {
      return await db
          .into(db.mangaCollections)
          .insert(
            MangaCollectionsCompanion.insert(
              name: normalized,
              createdAt: DateTime.now(),
            ),
          );
    } on Object catch (e) {
      if (e.toString().toLowerCase().contains('unique')) {
        throw StateError('收藏夹名称已存在');
      }
      rethrow;
    }
  }

  Future<void> rename(int id, String name) async {
    final normalized = _name(name);
    final duplicate =
        await (db.select(db.mangaCollections)
              ..where((t) => t.name.equals(normalized) & t.id.equals(id).not()))
            .getSingleOrNull();
    if (duplicate != null) throw StateError('收藏夹名称已存在');
    try {
      final changed =
          await (db.update(db.mangaCollections)..where((t) => t.id.equals(id)))
              .write(MangaCollectionsCompanion(name: Value(normalized)));
      if (changed == 0) throw StateError('收藏夹不存在');
    } on Object catch (e) {
      if (e.toString().toLowerCase().contains('unique')) {
        throw StateError('收藏夹名称已存在');
      }
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    await (db.delete(db.mangaCollections)..where((t) => t.id.equals(id))).go();
  }

  Future<void> addWorks(int id, Iterable<String> workIds) async {
    await db.transaction(() async {
      final collection = await (db.select(
        db.mangaCollections,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (collection == null) throw StateError('收藏夹不存在');
      for (final workId in workIds.toSet()) {
        final work = await (db.select(
          db.works,
        )..where((t) => t.id.equals(workId))).getSingleOrNull();
        if (work == null) throw StateError('作品不存在：$workId');
        if (work.type != 'manga') throw StateError('收藏夹只能添加漫画');
      }
      for (final workId in workIds.toSet()) {
        await db.customUpdate(
          'INSERT OR IGNORE INTO manga_collection_entries (collection_id, work_id) VALUES (?, ?)',
          variables: [Variable.withInt(id), Variable.withString(workId)],
          updates: {db.mangaCollectionEntries},
        );
      }
    });
  }

  Future<void> removeWorks(int id, Iterable<String> workIds) async {
    await db.transaction(() async {
      final collection = await (db.select(
        db.mangaCollections,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (collection == null) throw StateError('收藏夹不存在');
      for (final workId in workIds.toSet()) {
        await db.customUpdate(
          'DELETE FROM manga_collection_entries WHERE collection_id = ? AND work_id = ?',
          variables: [Variable.withInt(id), Variable.withString(workId)],
          updates: {db.mangaCollectionEntries},
        );
      }
    });
  }

  Stream<List<MangaCollectionSummary>> watchCollections() {
    return db
        .customSelect(
          'SELECT c.id, c.name, COUNT(w.id) AS item_count '
          'FROM manga_collections c LEFT JOIN manga_collection_entries e '
          'ON e.collection_id = c.id LEFT JOIN works w '
          "ON w.id = e.work_id AND w.type = 'manga' "
          'GROUP BY c.id ORDER BY c.created_at, c.id',
          readsFrom: {db.mangaCollections, db.mangaCollectionEntries, db.works},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              MangaCollectionSummary(
                id: row.read<int>('id'),
                name: row.read<String>('name'),
                count: row.read<int>('item_count'),
              ),
          ],
        );
  }

  Future<Set<int>> collectionsForWork(String workId) async {
    final rows = await db
        .customSelect(
          'SELECT collection_id FROM manga_collection_entries WHERE work_id = ?',
          variables: [Variable.withString(workId)],
          readsFrom: {db.mangaCollectionEntries},
        )
        .get();
    return {for (final row in rows) row.read<int>('collection_id')};
  }
}

final mangaCollectionsRepositoryProvider = Provider<MangaCollectionsRepository>(
  (ref) => MangaCollectionsRepository(ref.watch(appDatabaseProvider)),
);

final mangaCollectionsProvider = StreamProvider<List<MangaCollectionSummary>>(
  (ref) => ref.watch(mangaCollectionsRepositoryProvider).watchCollections(),
);

void refreshMangaCollectionShelf(ProviderContainer container) {
  container.read(shelfWorksCacheProvider).clear();
  container.read(shelfCacheEpochProvider.notifier).bump();
  container.invalidate(shelfWorksProvider);
  container.invalidate(shelfTotalProvider);
  container.read(shelfPageProvider.notifier).go(1);
}

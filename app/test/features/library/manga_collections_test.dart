import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/library/manga_collections.dart';
import 'package:mandu_reader/features/library/shelf_query.dart';
import 'package:mandu_reader/features/providers.dart';

void main() {
  late AppDatabase db;
  late MangaCollectionsRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = MangaCollectionsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> addWork(String id, String type, {String? title}) => db
      .into(db.works)
      .insert(
        WorksCompanion(
          id: Value(id),
          type: Value(type),
          title: Value(title ?? id),
        ),
      );

  test(
    'creates collection, accepts cloud manga, and adds members idempotently',
    () async {
      await addWork('manga-1', 'manga');
      final id = await repository.create('  Later  ');
      await repository.addWorks(id, ['manga-1', 'manga-1']);
      final secondId = await repository.create('Also later');
      await repository.addWorks(secondId, ['manga-1']);
      expect(await repository.collectionsForWork('manga-1'), {id, secondId});
      final summaries = await repository.watchCollections().first;
      expect(summaries.map((item) => (item.name, item.count)).toSet(), {
        ('Later', 1),
        ('Also later', 1),
      });
      await repository.removeWorks(id, ['manga-1']);
      expect(await repository.collectionsForWork('manga-1'), {secondId});
    },
  );

  test(
    'rejects empty or duplicate names and non-manga or missing works',
    () async {
      await expectLater(repository.create('  '), throwsArgumentError);
      final id = await repository.create('Reading');
      await expectLater(repository.create('Reading'), throwsStateError);
      final anotherId = await repository.create('Another');
      await expectLater(repository.rename(id, 'Another'), throwsStateError);
      await expectLater(repository.rename(id, '  '), throwsArgumentError);
      await repository.rename(anotherId, ' Renamed ');
      await addWork('novel-1', 'novel');
      await expectLater(repository.addWorks(id, ['novel-1']), throwsStateError);
      await expectLater(repository.addWorks(id, ['missing']), throwsStateError);
    },
  );

  test(
    'adding a batch with any invalid work rolls back every addition',
    () async {
      await addWork('manga-1', 'manga');
      await addWork('manga-2', 'manga');
      final id = await repository.create('Atomic');
      await expectLater(
        repository.addWorks(id, ['manga-1', 'missing', 'manga-2']),
        throwsStateError,
      );
      expect(await repository.collectionsForWork('manga-1'), isEmpty);
      expect(await repository.collectionsForWork('manga-2'), isEmpty);
    },
  );

  test(
    'deleting a collection preserves work and deleting work clears membership',
    () async {
      await addWork('manga-1', 'manga');
      final id = await repository.create('Shelf');
      await repository.addWorks(id, ['manga-1']);
      await repository.delete(id);
      expect(
        await (db.select(
          db.works,
        )..where((t) => t.id.equals('manga-1'))).getSingleOrNull(),
        isNotNull,
      );
      final second = await repository.create('Shelf 2');
      await repository.addWorks(second, ['manga-1']);
      await (db.delete(db.works)..where((t) => t.id.equals('manga-1'))).go();
      expect(await repository.collectionsForWork('manga-1'), isEmpty);
    },
  );

  test(
    'watch stream emits member changes and work deletion trigger updates count',
    () async {
      await addWork('manga-1', 'manga');
      final id = await repository.create('Watched');
      final stream = repository.watchCollections();
      final initial = await stream.first;
      expect(initial.single.count, 0);
      final afterAdd = stream.firstWhere((items) => items.single.count == 1);
      await repository.addWorks(id, ['manga-1']);
      expect((await afterAdd).single.count, 1);
      final afterRemove = stream.firstWhere((items) => items.single.count == 0);
      await repository.removeWorks(id, ['manga-1']);
      expect((await afterRemove).single.count, 0);
      await repository.addWorks(id, ['manga-1']);
      final afterDelete = stream.firstWhere((items) => items.single.count == 0);
      await (db.delete(db.works)..where((t) => t.id.equals('manga-1'))).go();
      expect((await afterDelete).single.count, 0);
    },
  );

  test(
    'persists collections and entries after reopening the database',
    () async {
      final dir = await Directory.systemTemp.createTemp('manga-collections-');
      final path = '${dir.path}/library.sqlite';
      await db.close();
      db = AppDatabase(NativeDatabase(File(path)));
      repository = MangaCollectionsRepository(db);
      await addWork('manga-1', 'manga');
      final id = await repository.create('Persisted');
      await repository.addWorks(id, ['manga-1']);
      await db.close();
      db = AppDatabase(NativeDatabase(File(path)));
      repository = MangaCollectionsRepository(db);
      expect(await repository.collectionsForWork('manga-1'), {id});
      expect(
        (await repository.watchCollections().first).single.name,
        'Persisted',
      );
      await db.close();
      await dir.delete(recursive: true);
    },
  );

  test(
    'migrates a v4 database to v5 without changing existing works',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'manga-collections-v4-',
      );
      final path = '${dir.path}/library.sqlite';
      await db.close();
      db = AppDatabase(NativeDatabase(File(path)));
      await addWork('legacy-manga', 'manga');
      await db.customStatement(
        'DROP TRIGGER IF EXISTS manga_collection_delete',
      );
      await db.customStatement(
        'DROP TRIGGER IF EXISTS manga_collection_work_delete',
      );
      await db.customStatement('DROP TABLE manga_collection_entries');
      await db.customStatement('DROP TABLE manga_collections');
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();
      db = AppDatabase(NativeDatabase(File(path)));
      expect(
        await (db.select(
          db.works,
        )..where((t) => t.id.equals('legacy-manga'))).getSingleOrNull(),
        isNotNull,
      );
      expect(
        await MangaCollectionsRepository(db).watchCollections().first,
        isEmpty,
      );
      await db.close();
      await dir.delete(recursive: true);
    },
  );

  test(
    'collection filter applies SQL pagination and totals only to manga',
    () async {
      await addWork('m1', 'manga', title: 'Dragon One');
      await addWork('m2', 'manga', title: 'Dragon Two');
      await addWork('m3', 'manga', title: 'Other Manga');
      await addWork('n1', 'novel');
      await addWork('n2', 'novel');
      final id = await repository.create('Filtered');
      await repository.addWorks(id, ['m1', 'm2']);

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container
          .read(shelfFilterProvider.notifier)
          .apply(
            ShelfFilter(type: 'manga', collectionId: id, sort: ShelfSort.title),
          );
      container.read(shelfPageSizeProvider.notifier).set(1);
      final pageOne = await container.read(shelfWorksProvider.future);
      expect(pageOne.map((work) => work.id), ['m1']);
      expect(await container.read(shelfTotalProvider.future), 2);

      container.read(shelfPageProvider.notifier).go(2);
      final pageTwo = await container.read(shelfWorksProvider.future);
      expect(pageTwo.map((work) => work.id), ['m2']);
      expect(
        pageOne
            .map((work) => work.id)
            .toSet()
            .intersection(pageTwo.map((work) => work.id).toSet()),
        isEmpty,
      );

      container.read(shelfPageProvider.notifier).go(1);
      container
          .read(shelfFilterProvider.notifier)
          .apply(
            ShelfFilter(
              type: 'manga',
              collectionId: id,
              query: 'Dragon',
              sort: ShelfSort.title,
            ),
          );
      expect(await container.read(shelfTotalProvider.future), 2);
      expect((await container.read(shelfWorksProvider.future)).single.id, 'm1');
      container
          .read(shelfFilterProvider.notifier)
          .apply(
            ShelfFilter(
              type: 'manga',
              collectionId: id,
              query: 'Other',
              sort: ShelfSort.title,
            ),
          );
      expect(await container.read(shelfTotalProvider.future), 0);
      expect(await container.read(shelfWorksProvider.future), isEmpty);

      container
          .read(shelfFilterProvider.notifier)
          .apply(ShelfFilter(type: 'novel', collectionId: id));
      expect(await container.read(shelfTotalProvider.future), 2);
      container
          .read(shelfFilterProvider.notifier)
          .apply(const ShelfFilter(type: 'manga', collectionId: -1));
      expect(await container.read(shelfTotalProvider.future), 1);

      container
          .read(shelfFilterProvider.notifier)
          .apply(ShelfFilter(type: 'manga', collectionId: id));
      await container.read(shelfWorksProvider.future);
      container.read(shelfPageProvider.notifier).go(2);
      refreshMangaCollectionShelf(container);
      expect(container.read(shelfPageProvider), 1);
      expect((await container.read(shelfWorksProvider.future)), hasLength(1));
      await repository.removeWorks(id, ['m1', 'm2']);
      refreshMangaCollectionShelf(container);
      expect(await container.read(shelfWorksProvider.future), isEmpty);
      expect(await container.read(shelfTotalProvider.future), 0);
    },
  );
}

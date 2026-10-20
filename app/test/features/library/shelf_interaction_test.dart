import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/downloader/jm_tasks.dart';
import 'package:mandu_reader/features/library/local_sweep.dart';
import 'package:mandu_reader/features/library/shelf_page.dart';
import 'package:mandu_reader/features/library/shelf_query.dart';
import 'package:mandu_reader/features/library/upload_tasks.dart';
import 'package:mandu_reader/features/providers.dart';
import 'package:mandu_reader/features/settings/settings_repository.dart';

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('旧漫画页签设置不覆盖默认小说，点击漫画立即切换且阅读按钮固定可见', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final root = await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('mandu_shelf_test_');
      final repo = SettingsRepository(db);
      await repo.set('storage.local_dir', root.path);
      await repo.set('shelf.tab', 'manga');
      await db
          .into(db.works)
          .insert(
            WorksCompanion.insert(
              id: 'jm_1454653',
              type: 'manga',
              title: '测试漫画详情',
            ),
          );
      await db.customStatement(
        "UPDATE works SET tags = ?, local_only = 1, origin = 'source:jmcomic', author = ?, series = ?, pages = 1201",
        [jsonEncode(List.generate(40, (i) => '标签 $i')), '测试作者', '测试系列'],
      );
      return root;
    });
    markHousekeepingRan();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bucketClientProvider.overrideWithValue(null),
        activeJmTaskCountProvider.overrideWithValue(0),
        activeUploadTaskCountProvider.overrideWithValue(0),
      ],
    );
    final router = GoRouter(
      initialLocation: '/shelf',
      routes: [
        GoRoute(path: '/shelf', builder: (_, _) => const ShelfPage()),
        GoRoute(
          path: '/reader',
          builder: (_, state) =>
              Scaffold(body: Text('已打开 ${(state.extra! as Work).id}')),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await _frames(tester);
      router.dispose();
      container.dispose();
      await tester.runAsync(db.close);
      await root!.delete(recursive: true);
    });
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _frames(tester);
    Set<String> selected() => tester
        .widget<SegmentedButton<String>>(
          find.byWidgetPredicate(
            (w) =>
                w is SegmentedButton<String> &&
                w.segments.any((s) => s.value == 'jm'),
          ),
        )
        .selected;
    expect(selected(), {'novel'});
    expect(container.read(shelfFilterProvider).type, 'novel');
    expect(find.text('测试漫画详情'), findsNothing);
    await tester.tap(find.text('漫画').first);
    await _frames(tester);
    expect(selected(), {'manga'});
    expect(container.read(shelfFilterProvider).type, 'manga');
    expect(find.text('测试漫画详情'), findsOneWidget);
    await tester.tap(find.text('测试漫画详情'));
    await _frames(tester);
    final read = find.widgetWithText(FilledButton, '阅读');
    expect(read.hitTestable(), findsOneWidget);
    final initial = tester.getRect(read);
    expect(initial.bottom, lessThanOrEqualTo(800));
    final sheet = find.byWidgetPredicate(
      (w) => w is SizedBox && w.height == 560,
    );
    expect(sheet, findsOneWidget);
    final initialSheet = tester.getRect(sheet);
    expect(find.text('JM 车号'), findsOneWidget);
    expect(find.text('1454653'), findsOneWidget);
    expect(find.text('标签 39'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('work-tags-toggle')));
    await tester.tap(find.byKey(const ValueKey('work-tags-toggle')));
    await _frames(tester);
    expect(find.text('标签 39'), findsOneWidget);
    expect(tester.getRect(sheet), initialSheet);
    expect(tester.getRect(read), initial);
    tester.view.physicalSize = const Size(600, 1200);
    await _frames(tester);
    expect(tester.getSize(sheet).height, 560);
    expect(read.hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('work-tags-toggle')));
    await tester.tap(find.byKey(const ValueKey('work-tags-toggle')));
    await _frames(tester);
    expect(find.text('标签 39'), findsNothing);
    final pinned = tester.getRect(read);
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await _frames(tester);
    expect(tester.getRect(read), pinned);
    await tester.tap(read);
    await _frames(tester);
    expect(find.text('已打开 jm_1454653'), findsOneWidget);
  });
}

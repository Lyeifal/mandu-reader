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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('漫画收藏夹支持管理、详情加入、批量加入移出、空夹返回且窄屏无溢出', (tester) async {
    final fixture = await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      final root = await Directory.systemTemp.createTemp(
        'mandu_collection_test_',
      );
      await SettingsRepository(db).set('storage.local_dir', root.path);
      for (final entry in [
        ('manga_1', '第一部'),
        ('manga_2', '第二部'),
        ('novel_1', '小说测试'),
      ]) {
        await db
            .into(db.works)
            .insert(
              WorksCompanion.insert(
                id: entry.$1,
                type: entry.$1.startsWith('manga') ? 'manga' : 'novel',
                title: entry.$2,
              ),
            );
      }
      await db.customStatement(
        "UPDATE works SET local_only = 1, origin = 'manual', pages = 10 WHERE type = 'manga'",
      );
      return (db: db, root: root);
    });
    final db = fixture!.db;
    final root = fixture.root;
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
              Scaffold(body: Text((state.extra! as Work).id)),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      await tester.runAsync(() async {
        await db.close();
        await root.delete(recursive: true);
      });
    });
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('漫画').first);
    await _settle(tester);
    expect(find.byKey(const ValueKey('manga-collection-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ActionChip, '管理'));
    await _settle(tester);
    await tester.tap(find.text('新建收藏夹'));
    await tester.enterText(find.byType(TextField).last, '待读');
    await tester.tap(find.text('保存'));
    await _settle(tester);
    await tester.tap(find.text('完成'));
    await _settle(tester);

    await tester.tap(find.text('第一部'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('work-add-to-collection')));
    await _settle(tester);
    await tester.tap(find.text('待读').last);
    await _settle(tester);
    expect(find.textContaining('已收藏：待读'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);

    await tester.longPress(find.text('第一部'));
    await _settle(tester);
    await tester.tap(find.text('第二部'));
    await _settle(tester);
    await tester.tap(find.byTooltip('加入收藏夹'));
    await _settle(tester);
    await tester.tap(find.text('待读').last);
    await _settle(tester);
    expect(find.text('已加入收藏夹'), findsOneWidget);

    await tester.tap(find.textContaining('待读 (2)'));
    await _settle(tester);
    await tester.longPress(find.text('第一部'));
    await _settle(tester);
    await tester.tap(find.byTooltip('从当前收藏夹移出'));
    await _settle(tester);
    expect(container.read(shelfFilterProvider).collectionId, greaterThan(0));
    expect(find.text('第一部'), findsNothing);
    await tester.longPress(find.text('第二部'));
    await _settle(tester);
    await tester.tap(find.byTooltip('从当前收藏夹移出'));
    await _settle(tester);
    expect(find.text('没有匹配的作品'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '全部漫画'));
    await _settle(tester);
    expect(find.text('第一部'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '待读 (0)'));
    await _settle(tester);
    await tester.ensureVisible(find.widgetWithText(ActionChip, '管理'));
    await tester.tap(find.widgetWithText(ActionChip, '管理'));
    await _settle(tester);
    await tester.tap(find.byTooltip('重命名 待读'));
    await tester.enterText(find.byType(TextField).last, '稍后看');
    await tester.tap(find.text('保存'));
    await _settle(tester);
    await tester.tap(find.byTooltip('删除 稍后看'));
    await _settle(tester);
    expect(find.textContaining('漫画文件会保留'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await _settle(tester);
    expect(container.read(shelfFilterProvider).collectionId, 0);
    await tester.tap(find.text('完成'));
    await _settle(tester);
    await tester.tap(find.text('未归类'));
    await _settle(tester);
    expect(find.text('第一部'), findsOneWidget);
    await tester.tap(find.text('小说').first);
    await _settle(tester);
    expect(find.byKey(const ValueKey('manga-collection-bar')), findsNothing);
    expect(find.byKey(const ValueKey('work-add-to-collection')), findsNothing);
    await tester.longPress(find.text('小说测试'));
    await _settle(tester);
    expect(find.byTooltip('加入收藏夹'), findsNothing);
    await tester.tap(find.byTooltip('取消选择'));
    await _settle(tester);
    await tester.tap(find.text('漫画').first);
    await _settle(tester);
    await tester.longPress(find.text('第一部'));
    await _settle(tester);
    await tester.tap(find.byTooltip('加入收藏夹'));
    await _settle(tester);
    await tester.tap(find.text('新建收藏夹'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await _settle(tester);
    expect(find.text('收藏夹名称不能为空'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '随时看');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await _settle(tester);
    expect(find.widgetWithText(ChoiceChip, '随时看 (1)'), findsOneWidget);
    expect(find.text('已加入收藏夹'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

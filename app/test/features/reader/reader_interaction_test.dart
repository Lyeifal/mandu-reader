import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/providers.dart';
import 'package:mandu_reader/features/reader/reader_page.dart';
import 'package:mandu_reader/features/settings/settings_repository.dart';

const _work = Work(
  id: 'reader_fixture',
  type: 'manga',
  title: '测试漫画',
  titleJp: '',
  author: '',
  series: '',
  tags: '[]',
  status: 'completed',
  pages: 1201,
  origin: 'manual',
  localOnly: true,
  hasZh: true,
  zhQuality: 'medium',
);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  late Directory root;
  late AppDatabase db;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mandu_reader_gestures_');
    final dir = Directory('${root.path}/${_work.id}')..createSync();
    final images = [
      for (var i = 0; i < 3; i++) img.encodePng(img.Image(12, 18 + i * 12)),
    ];
    for (var i = 0; i < 1201; i++) {
      File('${dir.path}/${i.toString().padLeft(4, '0')}.png')
          .writeAsBytesSync(images[i % images.length]);
    }
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final settings = SettingsRepository(db);
    await settings.set('storage.local_dir', root.path);
    await settings.set('reader.manga.autoPageIntervalSeconds', '0');
    await settings.set('reader.manga.scrollPercent', '50');
  });
  tearDown(() => db.close());
  tearDownAll(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await root.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    bool horizontal = false,
    Size size = const Size(1000, 1000),
  }) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (horizontal) {
      await tester.runAsync(
        () => SettingsRepository(db).set('reader.manga.mode', 'horizontal'),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bucketClientProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: ReaderPage(work: _work)),
      ),
    );
    await _frames(tester);
    for (var i = 0; i < 10 && find.byType(Scrollable).evaluate().isEmpty; i++) {
      await _frames(tester);
    }
    expect(find.byType(Scrollable), findsWidgets);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await _frames(tester);
    });
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await _frames(tester);
  }

  testWidgets('两侧拖动跟手，点按按视口百分比翻屏，中间显示操作说明', (tester) async {
    await open(tester);
    ScrollPosition pos() => tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .position;
    for (final x in [40.0, 960.0]) {
      final before = pos().pixels;
      final gesture = await tester.startGesture(Offset(x, 600));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, -160));
      await tester.pump();
      expect(pos().pixels, greaterThan(before + 80));
      await gesture.up();
      await _frames(tester);
    }
    final before = pos().pixels;
    final viewport = pos().viewportDimension;
    await tester.tapAt(const Offset(960, 500));
    await _frames(tester);
    expect(pos().pixels - before, closeTo(viewport * 0.5, 2));
    await tester.tapAt(const Offset(500, 450));
    await _frames(tester);
    expect(find.textContaining('单指滑动浏览'), findsOneWidget);
    await close(tester);
  });

  testWidgets('千页滑条预览不移动轨道，松手精确跳到目标，仍可向前向后阅读', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(500, 450));
    await _frames(tester);
    final finder = find.byKey(const ValueKey('manga-page-slider'));
    final originalRect = tester.getRect(finder);
    var slider = tester.widget<Slider>(finder);
    slider.onChangeStart!(0);
    slider.onChanged!(999);
    await tester.pump();
    expect(tester.getRect(finder), originalRect);
    expect(tester.widget<Slider>(finder).value, 999);
    slider.onChangeEnd!(999);
    await _frames(tester);
    expect(find.text('1000/1201'), findsOneWidget);
    final targetImage = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is FileImage &&
          (w.image as FileImage).file.path.endsWith('0999.png'),
    );
    expect(targetImage, findsOneWidget);
    expect(tester.getTopLeft(targetImage).dy, closeTo(0, 1));
    final scroll = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(scroll.controller!.offset, closeTo(0, 1));
    expect(scroll.controller!.position.minScrollExtent, lessThan(0));
    await tester.tapAt(const Offset(500, 450));
    await _frames(tester);
    await tester.timedDragFrom(
      const Offset(40, 500),
      const Offset(0, 250),
      const Duration(milliseconds: 300),
    );
    await _frames(tester);
    expect(scroll.controller!.offset, lessThan(0));
    await tester.tapAt(const Offset(500, 450));
    await _frames(tester);
    final track = tester.getRect(finder);
    final drag = await tester.startGesture(track.center);
    await drag.moveTo(Offset(track.left + track.width * 0.8, track.center.dy));
    await tester.pump();
    final selectedPage = tester.widget<Slider>(finder).value.round() + 1;
    expect(tester.getRect(finder), track);
    await drag.up();
    await _frames(tester);
    expect(find.text('$selectedPage/1201'), findsOneWidget);
    final input = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '页码',
    );
    await tester.enterText(input, '1201');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _frames(tester);
    expect(find.text('1201/1201'), findsOneWidget);
    await close(tester);
    final saved = await db.select(db.readingProgress).getSingle();
    expect(jsonDecode(saved.loc)['page'], 1201);
  });

  testWidgets('横向边缘拖动可翻页，滑条与数字输入使用相同源页码', (tester) async {
    await open(tester, horizontal: true);
    final gesture = await tester.startGesture(const Offset(950, 500));
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await _frames(tester);
    final page = tester.widget<PageView>(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(page.controller!.page, closeTo(1, 0.01));
    await tester.tapAt(const Offset(500, 450));
    await _frames(tester);
    final finder = find.byKey(const ValueKey('manga-page-slider'));
    final slider = tester.widget<Slider>(finder);
    slider.onChangeStart!(1);
    slider.onChanged!(700);
    slider.onChangeEnd!(700);
    await _frames(tester);
    expect(page.controller!.page, closeTo(700, 0.01));
    expect(find.text('701/1201'), findsOneWidget);
    await close(tester);
  });

  testWidgets('双指缩放后单指平移，点按复位后恢复列表滚动', (tester) async {
    await open(tester);
    final left = await tester.startGesture(const Offset(350, 500), pointer: 10);
    final right = await tester.startGesture(
      const Offset(650, 500),
      pointer: 11,
    );
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await left.moveBy(const Offset(-30, -15));
      await right.moveBy(const Offset(30, 15));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await left.up();
    await right.up();
    await _frames(tester);
    InteractiveViewer viewer() =>
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(
      viewer().transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1.1),
    );
    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await tester.tapAt(const Offset(500, 450));
    await _frames(tester);
    expect(viewer().transformationController!.value.getMaxScaleOnAxis(), 1);
    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)).physics,
      isNull,
    );
    await close(tester);
  });

  testWidgets('对开滑条按源页定位，切换方向和连续模式保持同一页', (tester) async {
    await open(tester, horizontal: true);
    await tester.tapAt(const Offset(500, 450));
    await _frames(tester);
    final doubleMode = tester.widget<SegmentedButton<bool>>(
      find.byWidgetPredicate(
        (w) =>
            w is SegmentedButton<bool> &&
            w.segments.any(
              (s) => s.label is Text && (s.label! as Text).data == '对开',
            ),
      ),
    );
    doubleMode.onSelectionChanged!({true});
    await _frames(tester);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('manga-page-slider')),
    );
    expect(slider.max, 1200);
    slider.onChangeStart!(0);
    slider.onChanged!(1000);
    slider.onChangeEnd!(1000);
    await _frames(tester);
    expect(find.text('第 1001-1002 页/共 1201 页'), findsOneWidget);
    final direction = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    direction.onSelectionChanged!({'vertical'});
    await _frames(tester);
    expect(find.text('1001/1201'), findsOneWidget);
    final snap = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    snap.onSelectionChanged!({true});
    await _frames(tester);
    expect(
      tester.widget<PageView>(find.byType(PageView)).controller!.page,
      1000,
    );
    snap.onSelectionChanged!({false});
    await _frames(tester);
    expect(find.text('1001/1201'), findsOneWidget);
    await close(tester);
  });

  testWidgets('打开菜单或拖动滑条时自动翻页暂停', (tester) async {
    await open(tester, horizontal: true);
    await tester.tapAt(const Offset(500, 450));
    await _frames(tester);
    final auto = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    auto.onSelectionChanged!({3});
    await tester.pump(const Duration(seconds: 10));
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    expect(controller.page, 0);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('manga-page-slider')),
    );
    slider.onChangeStart!(0);
    slider.onChanged!(800);
    await tester.pump(const Duration(seconds: 10));
    expect(controller.page, 0);
    slider.onChangeEnd!(800);
    await _frames(tester);
    expect(controller.page, 800);
    await close(tester);
  });

  for (final horizontal in [false, true]) {
    testWidgets('两指分处页面两端且首指已开始滚动仍能缩放', (tester) async {
      await open(tester, horizontal: horizontal);
      final first = await tester.startGesture(
        const Offset(160, 300),
        pointer: 20,
      );
      await first.moveBy(
        horizontal ? const Offset(-30, 0) : const Offset(0, -30),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await first.moveBy(
        horizontal ? const Offset(-80, 0) : const Offset(0, -80),
      );
      await tester.pump(const Duration(milliseconds: 30));
      final second = await tester.startGesture(
        const Offset(860, 700),
        pointer: 21,
      );
      await tester.pump();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      for (var i = 0; i < 4; i++) {
        await second.moveBy(const Offset(25, 25));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1.1),
      );
      await first.up();
      await second.up();
      await _frames(tester);
      final before = viewer.transformationController!.value.storage[12];
      await tester.timedDragFrom(
        const Offset(500, 400),
        const Offset(-60, 0),
        const Duration(milliseconds: 200),
      );
      await _frames(tester);
      expect(
        viewer.transformationController!.value.storage[12],
        lessThan(before),
      );
      await close(tester);
    });
  }

  for (final size in [
    const Size(1280, 800),
    const Size(800, 1280),
    const Size(400, 800),
  ]) {
    testWidgets('菜单横向利用空间且提示不遮挡 ${size.width}x${size.height}', (tester) async {
      await open(tester, size: size);
      await tester.tapAt(Offset(size.width / 2, size.height / 3));
      await _frames(tester);
      final controls = tester.getRect(
        find.byKey(const ValueKey('manga-reader-controls')),
      );
      final hint = find.textContaining('点按中间');
      final hintRect = tester.getRect(hint);
      expect(
        tester.widget<Text>(hint).style!.fontSize,
        greaterThanOrEqualTo(20),
      );
      expect(hintRect.bottom, lessThan(controls.top));
      expect(controls.height, lessThanOrEqualTo(320));
      if (size.width >= 800) {
        expect(controls.height, lessThan(250));
        expect(
          tester.getTopLeft(find.text('方向')).dy,
          closeTo(tester.getTopLeft(find.text('浏览')).dy, 2),
        );
      }
      await close(tester);
    });
  }
}

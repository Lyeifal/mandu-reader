import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/reader/reader_page.dart';

void main() {
  group('isWideImage', () {
    test('阈值 1.4：边界两侧判定', () {
      expect(isWideImage(const Size(139, 100)), isFalse);
      expect(isWideImage(const Size(140, 100)), isTrue);
      expect(isWideImage(const Size(100, 100)), isFalse);
    });

    test('高度为 0 不判横图（防御除零）', () {
      expect(isWideImage(const Size(100, 0)), isFalse);
    });
  });

  group('computeSpreads（乐观配对）', () {
    test('全部未探测：两两配对', () {
      final s = computeSpreads(5, {});
      expect(s, [(first: 0, len: 2), (first: 2, len: 2), (first: 4, len: 1)]);
    });

    test('横图在首/中/尾：独占一页，其后重新配对', () {
      expect(computeSpreads(4, {0}), [
        (first: 0, len: 1),
        (first: 1, len: 2),
        (first: 3, len: 1),
      ]);
      expect(computeSpreads(4, {2}), [
        (first: 0, len: 2),
        (first: 2, len: 1),
        (first: 3, len: 1),
      ]);
      // 尾页横图：前一页落单 + 横图独占
      expect(computeSpreads(4, {3}), [
        (first: 0, len: 2),
        (first: 2, len: 1),
        (first: 3, len: 1),
      ]);
    });

    test('连续横图各自独占', () {
      expect(computeSpreads(4, {1, 2}), [
        (first: 0, len: 1),
        (first: 1, len: 1),
        (first: 2, len: 1),
        (first: 3, len: 1),
      ]);
    });

    test('探测前乐观配对、探测后分裂：总页覆盖不丢不重', () {
      // 8 页、第 3 页是横图：(0,1)(2)(3,4)(5,6)(7)
      final wide = {2};
      final s = computeSpreads(8, wide);
      expect(s, [
        (first: 0, len: 2),
        (first: 2, len: 1),
        (first: 3, len: 2),
        (first: 5, len: 2),
        (first: 7, len: 1),
      ]);
      final covered = [
        for (final sp in s)
          for (var j = 0; j < sp.len; j++) sp.first + j,
      ];
      expect(covered, [0, 1, 2, 3, 4, 5, 6, 7]);
    });

    test('0 页与 1 页的退化', () {
      expect(computeSpreads(0, {}), isEmpty);
      expect(computeSpreads(1, {}), [(first: 0, len: 1)]);
    });
  });

  group('spreadIndexForPage', () {
    final spreads = computeSpreads(8, {2}); // (0,1)(2)(3,4)(5,6)(7)

    test('首页/横图页/尾页映射', () {
      expect(spreadIndexForPage(spreads, 0), 0);
      expect(spreadIndexForPage(spreads, 1), 0); // 右半
      expect(spreadIndexForPage(spreads, 2), 1); // 横图独占
      expect(spreadIndexForPage(spreads, 3), 2);
      expect(spreadIndexForPage(spreads, 5), 3); // (5,6) 左半
      expect(spreadIndexForPage(spreads, 7), 4);
    });

    test('越界夹到首/尾', () {
      expect(spreadIndexForPage(spreads, -1), 0);
      expect(spreadIndexForPage(spreads, 99), 4);
      expect(spreadIndexForPage(const [], 0), 0);
    });
  });
}

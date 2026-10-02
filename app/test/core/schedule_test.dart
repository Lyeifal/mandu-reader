import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_core/schedule.dart';

void main() {
  group('delayUntilDaily（Worker 每日定时）', () {
    final at = DateTime(2026, 10, 3, 10, 30); // 上午 10:30

    test('当天未到点：等到今天', () {
      final d = delayUntilDaily('02:00', DateTime(2026, 10, 3, 0, 30));
      expect(d, const Duration(hours: 1, minutes: 30));
    });

    test('当天已过点：排到明天同一时刻', () {
      final d = delayUntilDaily('02:00', at);
      expect(d, const Duration(hours: 15, minutes: 30)); // 10:30 → 次日 02:00
    });

    test('正好到点：不睡（立刻跑）', () {
      final d = delayUntilDaily('02:00', DateTime(2026, 10, 3, 2, 0));
      expect(d, Duration.zero);
    });

    test('单数字小时与分钟格式均可', () {
      expect(
        delayUntilDaily('2:00', DateTime(2026, 10, 3, 1, 0)),
        const Duration(hours: 1),
      );
      expect(
        delayUntilDaily('23:59', DateTime(2026, 10, 3, 23, 58)),
        const Duration(minutes: 1),
      );
    });

    test('非法/越界输入抛 FormatException（启动即失败，不虚跑）', () {
      expect(() => delayUntilDaily('2点', at), throwsFormatException);
      expect(() => delayUntilDaily('25:00', at), throwsFormatException);
      expect(() => delayUntilDaily('02:60', at), throwsFormatException);
    });
  });
}

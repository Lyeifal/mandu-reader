import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/core/retry.dart';

void main() {
  test('首次成功不触发重试', () async {
    var calls = 0;
    final r = await withRetry(() async => ++calls, baseDelay: Duration.zero);
    expect(r, 1);
    expect(calls, 1);
  });

  test('失败两次后第三次成功', () async {
    var calls = 0;
    final r = await withRetry(() async {
      calls++;
      if (calls < 3) throw StateError('第 $calls 次失败');
      return calls;
    }, baseDelay: Duration.zero);
    expect(r, 3);
    expect(calls, 3);
  });

  test('重试耗尽后抛出最后一次异常', () async {
    var calls = 0;
    Object? err;
    try {
      await withRetry(
        () async {
          calls++;
          throw StateError('第 $calls 次失败');
        },
        attempts: 3,
        baseDelay: Duration.zero,
      );
    } on Object catch (e) {
      err = e;
    }
    expect(calls, 3);
    expect(err, isA<StateError>());
    expect((err as StateError).message, '第 3 次失败');
  });

  test('shouldRetry 返回 false 时立即抛出', () async {
    var calls = 0;
    Object? err;
    try {
      await withRetry(
        () async {
          calls++;
          throw ArgumentError('确定性错误');
        },
        baseDelay: Duration.zero,
        shouldRetry: (e) => e is! ArgumentError,
      );
    } on Object catch (e) {
      err = e;
    }
    expect(calls, 1);
    expect(err, isA<ArgumentError>());
  });

  test('onRetry 在每次重试前回调', () async {
    final attempts = <int>[];
    var calls = 0;
    await withRetry(
      () async {
        calls++;
        if (calls < 3) throw StateError('x');
      },
      baseDelay: Duration.zero,
      onRetry: (e, a) => attempts.add(a),
    );
    expect(attempts, [1, 2]);
  });
}

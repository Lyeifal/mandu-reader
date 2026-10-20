import 'dart:async';
import 'dart:collection';

/// FIFO 并发闸门；实例须由所有调用方共享，不能每本/每章重新创建。
class JmWorkQueue {
  JmWorkQueue(this.concurrency) {
    if (concurrency < 1) throw ArgumentError.value(concurrency, 'concurrency');
  }

  final int concurrency;
  final _waiting = Queue<Completer<void>>();
  int _active = 0;

  Future<T> run<T>(Future<T> Function() action) async {
    if (_active < concurrency) {
      _active++;
    } else {
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    }
    try {
      return await action();
    } finally {
      if (_waiting.isEmpty) {
        _active--;
      } else {
        // 将名额直接交给队首，避免新调用越过已经排队的任务。
        _waiting.removeFirst().complete();
      }
    }
  }
}

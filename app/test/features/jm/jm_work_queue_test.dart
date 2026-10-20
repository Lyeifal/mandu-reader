import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/jm/jm_work_queue.dart';

void main() {
  test('跨调用共享并发上限，FIFO 交接名额且失败不阻塞后续任务', () async {
    final queue = JmWorkQueue(2);
    final gates = List.generate(5, (_) => Completer<void>());
    final started = <int>[];
    var active = 0;
    var peak = 0;
    final jobs = [
      for (var i = 0; i < gates.length; i++)
        queue.run(() async {
          started.add(i);
          active++;
          if (active > peak) peak = active;
          try {
            await gates[i].future;
            if (i == 0) throw StateError('bad image');
            return i;
          } finally {
            active--;
          }
        }),
    ];
    final failure = expectLater(jobs[0], throwsStateError);
    expect(started, [0, 1]);
    gates[0].complete();
    await failure;
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1, 2]);
    gates[1].complete();
    expect(await jobs[1], 1);
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1, 2, 3]);
    gates[2].complete();
    expect(await jobs[2], 2);
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1, 2, 3, 4]);
    gates[3].complete();
    gates[4].complete();
    await Future.wait(jobs.skip(3));
    expect(peak, 2);
    expect(active, 0);
    expect(await queue.run(() async => 99), 99);
  });

  test('拒绝零并发', () {
    expect(() => JmWorkQueue(0), throwsArgumentError);
  });
}

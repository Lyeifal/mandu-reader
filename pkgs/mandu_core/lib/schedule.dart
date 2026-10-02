/// 每日定时调度的等待时长计算（纯函数，单测对象）。
///
/// compress_worker 默认每天 02:00 跑一轮：进程常驻、睡到点干活，
/// 比 cron/timer 更好部署（Restart=always 即可，死亡重算等待）。
library;

/// 到下一个每日 [hhmm]（服务器本地时区，格式 `HH:MM`）的等待时长。
/// 当天时间已过则排到明天；非法输入抛 FormatException（启动即失败，配置错误不虚跑）。
Duration delayUntilDaily(String hhmm, DateTime now) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
  if (m == null) {
    throw FormatException('SCHEDULE_AT 格式应为 HH:MM（收到: $hhmm）');
  }
  final h = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  if (h > 23 || minute > 59) {
    throw FormatException('SCHEDULE_AT 越界（收到: $hhmm）');
  }
  var next = DateTime(now.year, now.month, now.day, h, minute);
  if (next.isBefore(now)) {
    // 已过点 → 明天；正好到点 → 不睡立刻跑
    next = next.add(const Duration(days: 1));
  }
  return next.difference(now);
}

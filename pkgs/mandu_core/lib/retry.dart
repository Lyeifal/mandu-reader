/// 瞬时故障自动重试：压缩转码、桶 IO 的网络抖动、ffmpeg 偶发崩溃等。
///
/// [op] 抛异常时按指数退避（1×/2×/4×…，封顶 8 秒）等待后重跑，
/// 最多执行 [attempts] 次（含首次尝试）。重试耗尽后抛出最后一次的异常。
///
/// [shouldRetry] 返回 false 的错误（缺 ffmpeg 这类确定性失败）直接抛出，
/// 不做无谓重试；[onRetry] 在每次重试前回调（ attempt 为第几次重试，从 1 计）。
Future<T> withRetry<T>(
  Future<T> Function() op, {
  int attempts = 3,
  Duration baseDelay = const Duration(seconds: 1),
  bool Function(Object error)? shouldRetry,
  void Function(Object error, int attempt)? onRetry,
}) async {
  assert(attempts >= 1, 'attempts 至少为 1');
  for (var i = 1; ; i++) {
    try {
      return await op();
    } on Object catch (e) {
      if (i >= attempts || (shouldRetry != null && !shouldRetry(e))) rethrow;
      onRetry?.call(e, i);
      var wait = baseDelay * (1 << (i - 1));
      const cap = Duration(seconds: 8);
      if (wait > cap) wait = cap;
      await Future<void>.delayed(wait);
    }
  }
}

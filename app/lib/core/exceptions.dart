/// 统一存储异常层级（设计文档 §5.2）。
sealed class StorageException implements Exception {
  const StorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// 桶配置不完整或非法。
class BucketConfigException extends StorageException {
  const BucketConfigException(super.message, {super.cause});
}

/// 网络层失败：DNS、TLS、超时、5xx、签名拒绝等。
class ConnectionException extends StorageException {
  const ConnectionException(super.message, {super.cause});
}

/// 对象不存在或无权限读取。
class ObjectNotFoundException extends StorageException {
  const ObjectNotFoundException(super.message, {super.cause});
}

/// Content-MD5 校验不一致。
class ChecksumMismatchException extends StorageException {
  const ChecksumMismatchException(super.message, {super.cause});
}

/// 重试耗尽。
class RetryExhaustedException extends StorageException {
  const RetryExhaustedException(super.message, {super.cause});
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// PIN 错误（解密校验失败）。
class PinMismatchException implements Exception {
  const PinMismatchException();

  @override
  String toString() => 'PinMismatchException: PIN 错误或数据已损坏';
}

/// PIN 派生密钥 + AES-256-CBC + HMAC-SHA256（Encrypt-then-MAC）。
///
/// 设计文档 §2.1：SK 用 PIN 派生密钥加密后落 secure storage。
/// 盐与 IV 随机生成，随密文以 JSON 存储；MAC 覆盖 salt||iv||ct，
/// 篡改任何字段都会在解密前被 HMAC 检出。
class PinCrypto {
  PinCrypto._();

  static const payloadVersion = 1;
  static const keyIterations = 100000;
  static const keyLength = 32; // AES-256
  static const saltLength = 16;
  static const ivLength = 16;

  /// 可注入 [random] 以便测试复现。
  static List<int> randomBytes(int length, {Random? random}) {
    final r = random ?? Random.secure();
    return List<int>.generate(length, (_) => r.nextInt(256));
  }

  static List<int> deriveKey(
    String pin,
    List<int> salt, {
    int iterations = keyIterations,
  }) => _pbkdf2HmacSha256(utf8.encode(pin), salt, iterations, keyLength);

  /// RFC 2898 PBKDF2，伪随机函数为 HMAC-SHA256。
  /// package:crypto 未提供 PBKDF2，此处按规范手写（30 行），
  /// 以 RFC 7914 测试向量在单测中验证。
  static List<int> _pbkdf2HmacSha256(
    List<int> password,
    List<int> salt,
    int iterations,
    int dkLen,
  ) {
    const hLen = 32; // SHA-256 输出长度
    final blockCount = (dkLen + hLen - 1) ~/ hLen;
    final dk = BytesBuilder();
    for (var block = 1; block <= blockCount; block++) {
      var u = Hmac(
        sha256,
        password,
      ).convert(Uint8List.fromList([...salt, ..._int32Be(block)])).bytes;
      final t = List<int>.of(u);
      for (var i = 1; i < iterations; i++) {
        u = Hmac(sha256, password).convert(u).bytes;
        for (var j = 0; j < hLen; j++) {
          t[j] ^= u[j];
        }
      }
      dk.add(t);
    }
    return Uint8List.fromList(dk.toBytes().sublist(0, dkLen));
  }

  static List<int> _int32Be(int v) => [
    (v >> 24) & 0xff,
    (v >> 16) & 0xff,
    (v >> 8) & 0xff,
    v & 0xff,
  ];

  static String encrypt(String plaintext, String pin, {Random? random}) {
    final salt = randomBytes(saltLength, random: random);
    final iv = randomBytes(ivLength, random: random);
    final key = deriveKey(pin, salt);
    final encrypter = _encrypterFor(key);
    final ct = encrypter.encrypt(plaintext, iv: enc.IV(Uint8List.fromList(iv)));
    final mac = _mac(key, salt: salt, iv: iv, cipherText: ct.bytes);
    return jsonEncode({
      'v': payloadVersion,
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'ct': base64Encode(ct.bytes),
      'mac': base64Encode(mac),
    });
  }

  /// 解密失败（PIN 错误或数据损坏）时抛 [PinMismatchException]。
  static String decrypt(String payload, String pin) {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
    } on Object {
      throw const FormatException('payload 不是合法 JSON');
    }
    if (map['v'] != payloadVersion) {
      throw FormatException('不支持的 payload 版本: ${map['v']}');
    }
    final salt = base64Decode(map['salt'] as String);
    final iv = base64Decode(map['iv'] as String);
    final ct = base64Decode(map['ct'] as String);
    final mac = base64Decode(map['mac'] as String);
    final key = deriveKey(pin, salt);
    final expected = _mac(key, salt: salt, iv: iv, cipherText: ct);
    if (!_bytesEqual(expected, mac)) {
      throw const PinMismatchException();
    }
    final encrypter = _encrypterFor(key);
    return encrypter.decrypt(
      enc.Encrypted(Uint8List.fromList(ct)),
      iv: enc.IV(Uint8List.fromList(iv)),
    );
  }

  static enc.Encrypter _encrypterFor(List<int> key) => enc.Encrypter(
    enc.AES(enc.Key(Uint8List.fromList(key)), mode: enc.AESMode.cbc),
  );

  static List<int> _mac(
    List<int> key, {
    required List<int> salt,
    required List<int> iv,
    required List<int> cipherText,
  }) {
    final input = Uint8List(salt.length + iv.length + cipherText.length)
      ..setRange(0, salt.length, salt)
      ..setRange(salt.length, salt.length + iv.length, iv)
      ..setRange(
        salt.length + iv.length,
        salt.length + iv.length + cipherText.length,
        cipherText,
      );
    return Uint8List.fromList(Hmac(sha256, key).convert(input).bytes);
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/features/auth/pin_crypto.dart';

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // RFC 7914 测试向量（dkLen = 32）
    test('c=1 匹配已知向量', () {
      final dk = PinCrypto.deriveKey(
        'password',
        List<int>.of('salt'.codeUnits),
        iterations: 1,
      );
      expect(
        dk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('c=2 匹配已知向量', () {
      final dk = PinCrypto.deriveKey(
        'password',
        List<int>.of('salt'.codeUnits),
        iterations: 2,
      );
      expect(
        dk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });
  });

  group('PinCrypto 加解密', () {
    final random = Random(42);

    test('往返一致', () {
      final payload = PinCrypto.encrypt(
        'my-secret-key',
        '123456',
        random: random,
      );
      expect(PinCrypto.decrypt(payload, '123456'), 'my-secret-key');
    });

    test('错误 PIN 抛 PinMismatchException', () {
      final payload = PinCrypto.encrypt(
        'my-secret-key',
        '123456',
        random: Random(7),
      );
      expect(
        () => PinCrypto.decrypt(payload, '654321'),
        throwsA(isA<PinMismatchException>()),
      );
    });

    test('同 PIN 同随机源 → 同密文（确定性，便于测试）', () {
      final a = PinCrypto.encrypt('sk', '0000', random: Random(9));
      final b = PinCrypto.encrypt('sk', '0000', random: Random(9));
      expect(a, b);
    });

    test('篡改密文被 HMAC 检出', () {
      final payload = PinCrypto.encrypt('topsecret', '2468', random: Random(3));
      // 结构化篡改：翻转 ct 值的首个 base64 字符后重新编码
      final map = Map<String, dynamic>.of(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      final ct = map['ct'] as String;
      map['ct'] = (ct.startsWith('A') ? 'B' : 'A') + ct.substring(1);
      final mutated = jsonEncode(map);
      expect(
        () => PinCrypto.decrypt(mutated, '2468'),
        throwsA(isA<PinMismatchException>()),
      );
    });

    test('非 JSON payload 抛 FormatException', () {
      expect(
        () => PinCrypto.decrypt('not-json', '1234'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

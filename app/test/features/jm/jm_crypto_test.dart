import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mandu_reader/features/jm/jm_crypto.dart';
import 'package:mandu_reader/features/jm/jm_scramble.dart';

Future<Map<String, dynamic>> _loadJson(String name) async {
  final f = File('test/fixtures/$name');
  return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
}

Uint8List _fixtureBytes(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

void main() {
  group('JmCrypto', () {
    test('解密 /album 型响应（固定 ts 向量）', () async {
      final v = await _loadJson('jm_crypto_vector.json');
      final out = JmCrypto.decodeRespData(
        v['data'] as String,
        v['ts'] as String,
      );
      expect(out, v['expect']);
    });

    test('解密域名下发响应（ts 为空串 + 专用密钥）', () async {
      final v = await _loadJson('jm_domain_vector.json');
      final out = JmCrypto.decodeRespData(
        v['data'] as String,
        v['ts'] as String,
        secret: v['secret'] as String,
      );
      expect(out, v['expect']);
      final json = jsonDecode(out) as Map<String, dynamic>;
      expect((json['Server'] as List).length, 2);
    });

    test('token 与 tokenparam 格式', () {
      final (token, tokenparam) = JmCrypto.tokenAndTokenparam('1700000000');
      expect(token, JmCrypto.md5hex('1700000000${JmCrypto.tokenSecret}'));
      expect(tokenparam, '1700000000,${JmCrypto.appVersion}');
    });
  });

  group('jmScrambleNum', () {
    test('分支：未加密 / 旧算法 / 新算法（Python 参考向量）', () {
      expect(jmScrambleNum(220980, 100000, '00001'), 0); // aid < scramble_id
      expect(jmScrambleNum(220980, 300000, '00001'), 16);
      expect(jmScrambleNum(220980, 400000, '00047'), 4);
      expect(jmScrambleNum(220980, 500000, '00123'), 10);
    });

    test('结果恒为偶数且在 2..20', () {
      for (var aid = 220981; aid < 600000; aid += 13751) {
        final n = jmScrambleNum(220980, aid, '00001');
        expect(n % 2, 0);
        expect(n, inInclusiveRange(2, 20));
      }
    });
  });

  group('jmDescramble/jmDecodeImage', () {
    test('golden：打乱图还原后与参考原图逐像素一致', () {
      final orig = img.decodeImage(_fixtureBytes('jm_scramble_orig.png'))!;
      final shuffled = img.decodeImage(
        _fixtureBytes('jm_scramble_shuffled.png'),
      )!;
      final decoded = jmDescramble(shuffled, 6);
      expect(decoded.width, orig.width);
      expect(decoded.height, orig.height);
      for (var y = 0; y < orig.height; y++) {
        for (var x = 0; x < orig.width; x++) {
          expect(
            decoded.getPixel(x, y),
            orig.getPixel(x, y),
            reason: 'pixel ($x,$y)',
          );
        }
      }
    });

    test('jmDecodeImage 输出可解码且尺寸正确', () {
      final shuffled = _fixtureBytes('jm_scramble_shuffled.png');
      final decoded = img.decodeImage(jmDecodeImage(shuffled, 6))!;
      expect(decoded.width, 64);
      expect(decoded.height, 50);
    });

    test('num=0（老图）原样返回', () {
      final orig = _fixtureBytes('jm_scramble_orig.png');
      expect(jmDecodeImage(orig, 0), orig);
    });
  });
}

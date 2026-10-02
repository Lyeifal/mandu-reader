import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// JM 移动端 API 加解密（移植自 jmcomic 的 JmCryptoTool）。
class JmCrypto {
  JmCrypto._();

  static const tokenSecret = '185Hcomic3PAPP7R';
  static const tokenSecret2 = '18comicAPPContent';
  static const dataSecret = '185Hcomic3PAPP7R';
  static const domainServerSecret = 'diosfjckwpqpdfjkvnqQjsik';
  static const appVersion = '2.1.7';

  static String md5hex(String s) => md5.convert(utf8.encode(s)).toString();

  /// 请求头 token/tokenparam。
  static (String, String) tokenAndTokenparam(
    String ts, {
    String ver = appVersion,
    String secret = tokenSecret,
  }) => (md5hex(ts + secret), '$ts,$ver');

  /// 解密接口返回的 data 字段：base64 → AES-128-ECB → 去 PKCS7。
  static String decodeRespData(
    String data,
    String ts, {
    String secret = dataSecret,
  }) {
    final b64 = base64.decode(data);
    final key = enc.Key(Uint8List.fromList(utf8.encode(md5hex(ts + secret))));
    final aes = enc.AES(key, mode: enc.AESMode.ecb, padding: null);
    final plain = aes.decrypt(enc.Encrypted(b64));
    final pad = plain.last;
    return utf8.decode(plain.sublist(0, plain.length - pad));
  }
}

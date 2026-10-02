import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'jm_crypto.dart';

/// JM 图片打乱的条带数计算（移植自 JmImageTool.get_num）。
int jmScrambleNum(int scrambleId, int photoId, String filenameNoExt) {
  if (photoId < scrambleId) return 0; // 老图未加密
  if (photoId < 268850) return 10;
  final x = photoId < 421926 ? 10 : 8;
  final s = JmCrypto.md5hex('$photoId$filenameNoExt');
  return (s.codeUnitAt(s.length - 1) % x) * 2 + 2;
}

/// 条带重排核心（纯变换，便于逐像素单测）。
/// 打乱图 = 原图水平条带倒序叠放；还原 = 自底向上取、自顶向下贴回。
img.Image jmDescramble(img.Image src, int num) {
  final w = src.width;
  final h = src.height;
  final over = h % num;
  final move = h ~/ num;
  final out = img.Image(w, h);

  for (var i = 0; i < num; i++) {
    final ySrc = h - move * (i + 1) - over;
    var mh = move;
    var yDst = move * i;
    if (i == 0) {
      mh += over; // 底部条多带余数
    } else {
      yDst += over;
    }
    final strip = img.copyCrop(src, 0, ySrc, w, mh);
    for (var y = 0; y < mh; y++) {
      for (var x = 0; x < w; x++) {
        out.setPixel(x, yDst + y, strip.getPixel(x, y));
      }
    }
  }
  return out;
}

/// 还原打乱图字节：解码 → 条带重排 → JPEG q88 编码
/// （image 包无 webp 编码器，JPEG 远小于 PNG）。
/// num<=0（老图）或 gif 直接返回原字节。
Uint8List jmDecodeImage(Uint8List bytes, int num) {
  if (num <= 0) return bytes;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw FormatException('无法解码 JM 图片（${bytes.length} 字节）');
  }
  return Uint8List.fromList(
    img.encodeJpg(jmDescramble(decoded, num), quality: 88),
  );
}

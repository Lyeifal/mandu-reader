import 'dart:io';

/// 可替换的转码器（测试注入假实现）。
abstract class JmTranscoder {
  const JmTranscoder();

  /// 转码器是否可用（ffmpeg 可执行）。手机端未配置时应返回 false，
  /// 调用方据此跳过压缩、保留原图。
  Future<bool> available();

  /// 转码 [input] → [output]（调用方负责善后）。返回是否成功产出。
  Future<bool> transcode(String input, String output);

  /// 两图结构相似度（0~1），拿不到返回 null。
  Future<double?> ssim(String original, String compressed);
}

/// 判定是否用压缩结果替换原图（纯函数，单测对象）。
///
/// 规则（用户定义：体积优先但不做亏本买卖）：
/// - 压完比原图还大 → 不替换
/// - 节省 ≥ [generousSaving]（默认 50%）→ 直接替换，不再看 ssim
///   （用户定：30-50KB 对 150-300KB 这种小一个量级的必然赚）
/// - [ssim] 拿不到（尺寸不匹配等）→ 要求省至少 [strictSaving]（默认 40%）
/// - 画质损失明显（ssim < [ssimFloor]）但没省下多少
///   （节省 < [minSaving]，默认 30%）→ 不替换
/// - 其余情况替换
bool worthReplacing(
  int originalBytes,
  int compressedBytes,
  double? ssim, {
  double ssimFloor = 0.97,
  double minSaving = 0.30,
  double strictSaving = 0.40,
  double generousSaving = 0.50,
}) {
  if (compressedBytes >= originalBytes) return false;
  final saving = 1 - compressedBytes / originalBytes;
  if (saving >= generousSaving) return true;
  if (ssim == null) return saving >= strictSaving;
  if (ssim >= ssimFloor) return true;
  return saving >= minSaving;
}

/// ffmpeg AVIF 转码（漫读桶内页面格式）。
///
/// 档位：最小体积优先、不考虑耗时——libaom-av1 最慢档（cpu-used 0）+
/// crf 45 + yuv420p + still-picture，奇数尺寸裁 1px 到偶数（不补边）。
/// 参数源自 avif_core 的「日常级」框架，把质量档推向体积极限；调 crf 即可换挡。
class AvifTranscoder extends JmTranscoder {
  AvifTranscoder({this.ffmpegPath = 'ffmpeg'});

  final String ffmpegPath;

  static const minSizeCrf = '45';

  List<String> buildArgs(String input, String output) => [
    '-y',
    '-i',
    input,
    '-c:v',
    'libaom-av1',
    '-still-picture',
    '1',
    '-cpu-used',
    '0',
    '-row-mt',
    '1',
    '-crf',
    minSizeCrf,
    '-b:v',
    '0',
    '-pix_fmt',
    'yuv420p',
    '-aom-params',
    'tune=ssim:enable-qm=1:aq-mode=1',
    '-vf',
    'crop=iw-mod(iw\\,2):ih-mod(ih\\,2)',
    output,
  ];

  /// 探测 ffmpeg 可执行是否可用（空路径/进程起不来 = 不可用，不抛异常）。
  @override
  Future<bool> available() async {
    if (ffmpegPath.trim().isEmpty) return false;
    try {
      final r = await Process.run(ffmpegPath, ['-version']);
      return r.exitCode == 0;
    } on Object {
      return false;
    }
  }

  /// 转码单张图片为 AVIF。不做事后大小判断（由 [worthReplacing] 负责），
  /// 失败（ffmpeg 报错）抛 StateError。
  @override
  Future<bool> transcode(String input, String output) async {
    final result = await Process.run(ffmpegPath, buildArgs(input, output));
    if (result.exitCode != 0) {
      final err = result.stderr?.toString() ?? '';
      final tail = err.trim().split('\n').where((e) => e.isNotEmpty).toList();
      throw StateError(
        'ffmpeg 转码失败(${result.exitCode})：${tail.isEmpty ? '未知错误' : tail.last}',
      );
    }
    return true;
  }

  /// 计算两图的 SSIM（0~1）；尺寸不匹配等导致的失败返回 null。
  @override
  Future<double?> ssim(String original, String compressed) async {
    final result = await Process.run(ffmpegPath, [
      '-i',
      original,
      '-i',
      compressed,
      '-lavfi',
      'ssim',
      '-f',
      'null',
      '-',
    ]);
    if (result.exitCode != 0) return null;
    final err = result.stderr?.toString() ?? '';
    final m = RegExp(r'All:([0-9.]+)').firstMatch(err);
    return m == null ? null : double.tryParse(m.group(1)!);
  }
}

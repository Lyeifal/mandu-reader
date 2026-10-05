/// 书源 HTTP 层（dart:io，零 Flutter 依赖）。
///
/// 语义对照 so-novel CrawlUtils/OkHttpClientFactory：
/// - 每请求随机桌面 UA + Referer（=host）
/// - 每源请求间隔 min~max 随机（防反爬；实例级串行节流）
/// - 编码三级探测：Content-Type charset → <meta charset>（前 4KB） → UTF-8 兜底，
///   GBK/GB2312/GB18030 走 gbk_codec
/// - Cloudflare 特征标题检测（hasCf 同款集合）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:gbk_codec/gbk_codec.dart';

/// HTTP 抽象：Parser 只依赖本接口，测试用 FakeSourceHttp 顶替。
abstract class SourceHttp {
  /// GET 返回**已按编码解码**的响应体。
  Future<String> get(String url, {int timeoutSec = 15, String? cookie});

  /// POST 表单（Content-Type: application/x-www-form-urlencoded）。
  Future<String> post(
    String url,
    Map<String, String> form, {
    int timeoutSec = 15,
    String? cookie,
  });

  /// 下载字节（封面用）。
  Future<List<int>> getBytes(String url, {int timeoutSec = 30, String? cookie});
}

/// 真实实现；[proxy] 非空时全部请求走代理（仅 needProxy 源或 proxy_all）。
class SourceHttpClient implements SourceHttp {
  SourceHttpClient({
    this.proxy = '',
    this.minIntervalMs = 300,
    this.maxIntervalMs = 800,
    Random? random,
  }) : _random = random ?? Random();

  final String proxy;
  final int minIntervalMs;
  final int maxIntervalMs;
  final Random _random;

  /// 实例级节流：同一书源任意时刻一个请求在飞，间隔 min~max 随机。
  Future<void>? _chain;
  DateTime _lastStart = DateTime.fromMillisecondsSinceEpoch(0);

  static const _uas = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:127.0) Gecko/20100101 Firefox/127.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  ];

  Future<T> _throttled<T>(Future<T> Function() fn) {
    final prev = _chain ?? Future.value();
    final next = prev.then((_) async {
      final elapsed = DateTime.now().difference(_lastStart).inMilliseconds;
      final min = minIntervalMs.clamp(0, 60000);
      final max = maxIntervalMs.clamp(min, 60000);
      final wait = max > min ? min + _random.nextInt(max - min + 1) : min;
      if (elapsed < wait) {
        await Future<void>.delayed(Duration(milliseconds: wait - elapsed));
      }
      _lastStart = DateTime.now();
      return fn();
    });
    _chain = next.then((_) {}, onError: (_) {});
    return next;
  }

  Map<String, String> _headers(String url, String? cookie) {
    final uri = Uri.tryParse(url);
    final headers = <String, String>{
      'User-Agent': _uas[_random.nextInt(_uas.length)],
      'Accept-Language': 'zh-CN,zh;q=0.9',
      if (uri != null) 'Referer': '${uri.scheme}://${uri.host}',
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
    };
    return headers;
  }

  Future<HttpClient> _client() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    final p = proxy.trim();
    if (p.isNotEmpty) {
      final clean = p.replaceFirst(RegExp('^https?://'), '');
      client.findProxy = (_) => 'PROXY $clean';
    }
    return client;
  }

  @override
  Future<String> get(String url, {int timeoutSec = 15, String? cookie}) =>
      _throttled(() async {
        final client = await _client();
        try {
          final req = await client
              .getUrl(Uri.parse(url))
              .timeout(Duration(seconds: timeoutSec));
          _headers(url, cookie).forEach(req.headers.add);
          final resp = await req.close().timeout(Duration(seconds: timeoutSec));
          final bytes = await _readAll(resp, timeoutSec);
          _checkStatus(resp.statusCode, url);
          return decodeBody(bytes, resp.headers.contentType?.charset);
        } finally {
          client.close();
        }
      });

  @override
  Future<String> post(
    String url,
    Map<String, String> form, {
    int timeoutSec = 15,
    String? cookie,
  }) => _throttled(() async {
    final client = await _client();
    try {
      final req = await client
          .postUrl(Uri.parse(url))
          .timeout(Duration(seconds: timeoutSec));
      _headers(url, cookie).forEach(req.headers.add);
      req.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      req.write(
        Uri(queryParameters: form.map((k, v) => MapEntry(k, v.toString())))
            .query,
      );
      final resp = await req.close().timeout(Duration(seconds: timeoutSec));
      final bytes = await _readAll(resp, timeoutSec);
      _checkStatus(resp.statusCode, url);
      return decodeBody(bytes, resp.headers.contentType?.charset);
    } finally {
      client.close();
    }
  });

  @override
  Future<List<int>> getBytes(
    String url, {
    int timeoutSec = 30,
    String? cookie,
  }) => _throttled(() async {
    final client = await _client();
    try {
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(Duration(seconds: timeoutSec));
      _headers(url, cookie).forEach(req.headers.add);
      final resp = await req.close().timeout(Duration(seconds: timeoutSec));
      final bytes = await _readAll(resp, timeoutSec);
      _checkStatus(resp.statusCode, url);
      return bytes;
    } finally {
      client.close();
    }
  });

  Future<List<int>> _readAll(HttpClientResponse resp, int timeoutSec) async {
    final builder = BytesBuilder();
    // 体级超时：timeoutSec 只包到响应头，服务器「回了头卡死体」会让请求
    // 永久挂起，且实例节流链串行——一个僵尸请求拖死该源全部后续请求。
    // 按静默时长判死（timeoutSec 内无任何字节即 TimeoutException）。
    await for (final chunk in resp.timeout(Duration(seconds: timeoutSec))) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  void _checkStatus(int code, String url) {
    if (code < 200 || code >= 300) {
      throw StateError('HTTP $code: ${url.split('?').first}');
    }
  }
}

/// 响应体解码：header charset → meta charset → UTF-8 兜底。
String decodeBody(List<int> bytes, String? headerCharset) {
  var cs = headerCharset?.trim();
  cs ??= _metaCharset(bytes);
  if (cs != null) {
    final lower = cs.toLowerCase();
    if (lower == 'utf-8' || lower == 'utf8') {
      return utf8.decode(bytes, allowMalformed: true);
    }
    if (lower.startsWith('gb')) {
      try {
        return gbk_bytes.decode(bytes);
      } on Object {
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String? _metaCharset(List<int> bytes) {
  final head = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
  final text = latin1.decode(head, allowInvalid: true);
  final m = RegExp(
    "<meta[^>]+charset\\s*=\\s*['\"]?\\s*([\\w-]+)",
    caseSensitive: false,
  ).firstMatch(text);
  return m?.group(1);
}

/// Cloudflare 真人验证特征标题（so-novel hasCf 同款集合）。
const cfTitles = {
  'Just a moment...',
  '403 Forbidden',
  'Attention Required! | Cloudflare',
  'Checking your browser before accessing',
};

/// HTML 是否命中 CF 挑战页。
bool looksLikeCf(String html) {
  final m = RegExp(
    r'<title[^>]*>(.*?)</title>',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(html);
  if (m == null) return false;
  final title = m.group(1)!.trim();
  return cfTitles.any((t) => title.startsWith(t.split('|').first.trim()));
}

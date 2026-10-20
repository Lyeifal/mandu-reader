import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'jm_crypto.dart';
import 'jm_models.dart';

/// JM 图片 CDN 域名表（与 JmApiClient 内一致，独立函数供无实例场景使用）。
const jmImageDomains = [
  'cdn-msp.jmapiproxy1.cc',
  'cdn-msp.jmapiproxy2.cc',
  'cdn-msp2.jmapiproxy2.cc',
  'cdn-msp3.jmapiproxy2.cc',
  'cdn-msp.jmapinodeudzn.net',
  'cdn-msp3.jmapinodeudzn.net',
];

/// 本子封面 URL（无需 JmApiClient 实例）。
String jmAlbumCoverUrl(String albumId, {bool thumb = true}) {
  final domain = jmImageDomains[albumId.hashCode.abs() % jmImageDomains.length];
  return 'https://$domain/media/albums/$albumId${thumb ? '_3x4' : ''}.jpg';
}

/// JM 移动端 API 客户端（纯 Dart，移植自 jmcomic 的 JmApiClient 核心路径）。
///
/// 关键点：
/// - 请求头 token = md5(ts+密钥)，/chapter_view_template 用第二密钥；
/// - 响应体 base64 + AES-256-ECB（ASCII hex 形式的 md5 作 32 字节密钥）；
/// - 移动端 API 必须带 cookie（内容不校验，/setting 引导）；
/// - 单域名重试 5 次后切换，域名列表支持从域名服务器自动更新。
class JmApiClient {
  JmApiClient({String proxy = ''}) {
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    if (proxy.trim().isNotEmpty) {
      final p = proxy.trim().replaceFirst(RegExp('^https?://'), '');
      _client.findProxy = (url) => 'PROXY $p';
    }
  }

  late final HttpClient _client;

  static const _ua =
      'Mozilla/5.0 (Linux; Android 9; V1938CT Build/PQ3A.190705.11211812; wv) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/91.0.4472.114 '
      'Safari/537.36';

  static const _apiAlbum = '/album';
  static const _apiChapter = '/chapter';
  static const _apiScramble = '/chapter_view_template';

  static const _imageDomains = jmImageDomains;

  static const _defaultApiDomains = [
    'www.cdnhjk.net',
    'www.cdngwc.cc',
    'www.cdngwc.net',
    'www.cdngwc.club',
  ];

  static const _domainServers = [
    'https://rup4a04-c01.tos-ap-southeast-1.bytepluses.com/newsvr-2025.txt',
    'https://rup4a04-c02.tos-cn-hongkong.bytepluses.com/newsvr-2025.txt',
    'https://rup4a04-c03.tos-cn-beijing.bytepluses.com/newsvr-2025.txt',
  ];

  List<String> _apiDomains = List.of(_defaultApiDomains);
  String _cookie = '';
  bool _bootstrapped = false;
  final _scrambleCache = <String, int>{};
  final _rand = Random();

  /// 释放内部 HttpClient（下载器/浏览页用完即关，避免连接堆积）。
  void close() => _client.close(force: true);

  /// 初始化：尽力更新域名 + 引导 cookie。失败不致命（用内置域名重试）。
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await _updateDomains();
    await _ensureCookies();
  }

  Future<JmAlbumInfo> getAlbum(String albumId) async {
    final (json, ts) = await _apiGet('$_apiAlbum?id=$albumId');
    return JmAlbumInfo.fromJson(_decodeData(json, ts));
  }

  Future<JmPhotoInfo> getPhoto(String photoId) async {
    final (json, ts) = await _apiGet('$_apiChapter?id=$photoId');
    return JmPhotoInfo.fromJson(_decodeData(json, ts));
  }

  /// 取 scramble_id（进程内缓存，接口失败回退 220980）。
  Future<int> getScrambleId(String photoId) async {
    final hit = _scrambleCache[photoId];
    if (hit != null) return hit;

    final (text, _) = await _apiGetRaw(
      '$_apiScramble?id=$photoId&mode=vertical&page=0&app_img_shunt=1&express=off',
      scramble: true,
    );
    final m = RegExp(r'scramble_id\s*=\s*(\d+)').firstMatch(text);
    final id = m == null ? 220980 : int.parse(m.group(1)!);
    _scrambleCache[photoId] = id;
    return id;
  }

  /// 图片 URL（随机 CDN 域）。
  String imageUrl(String photoId, String filename) {
    final domain = _imageDomains[_rand.nextInt(_imageDomains.length)];
    return 'https://$domain/media/photos/$photoId/$filename';
  }

  /// 本子封面 URL（_3x4 为列表缩略图）。
  String albumCoverUrl(String albumId, {bool thumb = true}) {
    final domain = _imageDomains[_rand.nextInt(_imageDomains.length)];
    return 'https://$domain/media/albums/$albumId${thumb ? '_3x4' : ''}.jpg';
  }

  /// 无客户端实例时的封面 URL（浏览网格用，域名从静态表随机）。
  static String staticCoverUrl(String albumId, {bool thumb = true}) =>
      jmAlbumCoverUrl(albumId, thumb: thumb);

  /// 搜索：main_tag=1 时按标签搜；order: mr 最新 / mv 最多观看 / mp 图片数 /
  /// tf 最多喜欢 / md 最多评论；time: a 全部 / t 今天 / w 周 / m 月。
  Future<JmSearchPage> search(
    String query, {
    bool byTag = false,
    int page = 1,
    String order = 'mr',
    String time = 'a',
  }) async {
    final (json, ts) = await _apiGet(
      '/search?main_tag=${byTag ? 1 : 0}'
      '&search_query=${Uri.encodeQueryComponent(query)}'
      '&page=$page&o=$order&t=$time',
    );
    final data = _decodeData(json, ts);
    final sp = JmSearchPage.fromJson(data);
    return sp;
  }

  /// 排行/分类列表。c: 0 全部 / doujin 同人 / single 单本 / short 短篇 /
  /// another 其他 / hanman 韩漫 / meiman 美漫 / doujin_cosplay / 3D。
  Future<JmSearchPage> category(
    int page, {
    String category = '0',
    String order = 'mr',
    String time = 'a',
  }) async {
    final o = time == 'a' ? order : '${order}_$time';
    final (json, ts) = await _apiGet(
      '/categories/filter?page=$page&order=&c=$category&o=$o',
    );
    return JmSearchPage.fromJson(_decodeData(json, ts));
  }

  /// 下载图片字节（原样，不解密）。同 URL 重试 5 次。
  Future<Uint8List> downloadImage(String url) async {
    Object? last;
    final original = Uri.parse(url);
    final firstDomain = _imageDomains.indexOf(original.host);
    for (var i = 0; i < 5; i++) {
      try {
        // 一台 CDN 坏掉时换域名重试同一张图，避免整本被单页拖死。
        final candidate = original.replace(
          host:
              _imageDomains[(firstDomain < 0 ? 0 : firstDomain + i) %
                  _imageDomains.length],
        );
        final req = await _client.getUrl(candidate);
        _imageHeaders(candidate.toString()).forEach(req.headers.set);
        final resp = await req.close().timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200) {
          throw StateError('图片返回 ${resp.statusCode}');
        }
        final builder = BytesBuilder();
        await for (final chunk in resp.timeout(const Duration(seconds: 30))) {
          builder.add(chunk);
        }
        return builder.toBytes();
      } on Object catch (e) {
        last = e;
        if (i < 4) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (i + 1)));
        }
      }
    }
    throw StateError('图片下载失败: $url（$last）');
  }

  Map<String, String> _imageHeaders(String url) => {
    'user-agent': _ua,
    'Accept':
        'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'X-Requested-With': 'com.JMComic3.app',
    'Referer': 'https://${_apiDomains.first}',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  // ---------------------------------------------------------------- 内部

  Map<String, dynamic> _decodeData(Map<String, dynamic> json, String ts) {
    final data = json['data'];
    if (data is! String || data.isEmpty) {
      throw StateError('JM 响应缺少 data 字段');
    }
    final decoded = JmCrypto.decodeRespData(data, ts);
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  Future<(Map<String, dynamic>, String)> _apiGet(
    String pathAndQuery, {
    bool scramble = false,
  }) async {
    final (text, ts) = await _apiGetRaw(pathAndQuery, scramble: scramble);
    return ((jsonDecode(text) as Map<String, dynamic>), ts);
  }

  /// 带域名轮转的 GET；返回 (响应体文本, 本次请求的时间戳 ts)。
  /// ts 必须随返回值带出而不是存共享字段——下载器并发拉章时，
  /// 共享字段会被后启动的请求覆盖，导致用错密钥解密。
  Future<(String, String)> _apiGetRaw(
    String pathAndQuery, {
    bool scramble = false,
  }) async {
    Object? last;
    for (final domain in List.of(_apiDomains)) {
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
          final secret = scramble
              ? JmCrypto.tokenSecret2
              : JmCrypto.tokenSecret;
          final (token, tokenparam) = JmCrypto.tokenAndTokenparam(
            ts,
            secret: secret,
          );
          final req = await _client.getUrl(
            Uri.parse('https://$domain$pathAndQuery'),
          );
          req.headers.set('user-agent', _ua);
          req.headers.set('token', token);
          req.headers.set('tokenparam', tokenparam);
          if (_cookie.isNotEmpty) req.headers.set('cookie', _cookie);
          final resp = await req.close().timeout(const Duration(seconds: 30));
          final body = await utf8.decodeStream(
            resp.timeout(const Duration(seconds: 30)),
          );
          if (resp.statusCode != 200) {
            throw StateError('HTTP ${resp.statusCode}');
          }
          if (!scramble) {
            final first = body.trimLeft();
            if (first.isEmpty || first[0] != '{') {
              throw StateError(
                '响应不是 JSON：${body.substring(0, body.length > 120 ? 120 : body.length)}',
              );
            }
          }
          return (body, ts);
        } on Object catch (e) {
          last = e;
          await Future<void>.delayed(
            Duration(milliseconds: 200 * (attempt + 1)),
          );
        }
      }
    }
    throw StateError('JM API 请求失败 $pathAndQuery：$last');
  }

  Future<void> _ensureCookies() async {
    if (_cookie.isNotEmpty) return;
    try {
      final domain = _apiDomains.first;
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final (token, tokenparam) = JmCrypto.tokenAndTokenparam(ts);
      final req = await _client.getUrl(Uri.parse('https://$domain/setting'));
      req.headers.set('user-agent', _ua);
      req.headers.set('token', token);
      req.headers.set('tokenparam', tokenparam);
      final resp = await req.close().timeout(const Duration(seconds: 30));
      final cookies = <String>[];
      resp.headers.forEach((name, values) {
        if (name.toLowerCase() == 'set-cookie') {
          for (final v in values) {
            cookies.add(v.split(';').first);
          }
        }
      });
      await utf8.decodeStream(resp.timeout(const Duration(seconds: 30)));
      if (cookies.isNotEmpty) {
        _cookie = cookies.join('; ');
      }
    } on Object {
      // cookie 引导失败不阻塞，服务端不校验内容
    }
  }

  // ---------------------------------------------------------------- 账号

  bool _loggedIn = false;
  String _username = '';

  bool get isLoggedIn => _loggedIn;
  String get username => _username;

  /// 登录：POST /login，AVS cookie 即会话凭证。
  Future<JmLoginInfo> login(String username, String password) async {
    final body = <String, String>{'username': username, 'password': password};
    final r = await _apiPost('/login', body);
    final data = _decodeData(r.json, r.ts);
    final info = JmLoginInfo.fromJson(data);
    final s = (data['s'] ?? '').toString();
    if (s.isEmpty) throw StateError('登录响应缺少会话凭证');
    // 会话 = 基础 cookie + 登录响应 set-cookie + AVS=s（去掉旧 AVS 避免重复）
    final pairs = <String>[];
    void absorb(String cookieText) {
      for (final part in cookieText.split(';')) {
        final kv = part.trim();
        if (kv.isEmpty || kv.toLowerCase().startsWith('avs=')) continue;
        pairs.add(kv);
      }
    }

    if (_cookie.isNotEmpty) absorb(_cookie);
    for (final c in r.setCookies) {
      absorb(c);
    }
    pairs.add('AVS=$s');
    _cookie = pairs.join('; ');
    _loggedIn = true;
    _username = info.username.isEmpty ? username : info.username;
    return info;
  }

  /// 收藏夹列表。o: mr 收藏时间 / mp 更新时间。
  Future<JmFavoritePage> favorites({
    int page = 1,
    String folderId = '0',
    String order = 'mr',
  }) async {
    if (!_loggedIn) {
      throw StateError('请先登录 JM 账号');
    }
    final (json, ts) = await _apiGet(
      '/favorite?page=$page&folder_id=$folderId&o=$order',
    );
    return JmFavoritePage.fromJson(_decodeData(json, ts));
  }

  /// 带域名轮转的 POST（表单）。
  Future<({Map<String, dynamic> json, String ts, List<String> setCookies})>
  _apiPost(String path, Map<String, String> form) async {
    Object? last;
    for (final domain in List.of(_apiDomains)) {
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
          final (token, tokenparam) = JmCrypto.tokenAndTokenparam(ts);
          final req = await _client.postUrl(Uri.parse('https://$domain$path'));
          req.headers.set('user-agent', _ua);
          req.headers.set('token', token);
          req.headers.set('tokenparam', tokenparam);
          req.headers.contentType = ContentType(
            'application',
            'x-www-form-urlencoded',
          );
          req.write(Uri(queryParameters: form).query);
          final resp = await req.close().timeout(const Duration(seconds: 30));
          final body = await utf8.decodeStream(
            resp.timeout(const Duration(seconds: 30)),
          );
          final setCookies = <String>[];
          resp.headers.forEach((name, values) {
            if (name.toLowerCase() == 'set-cookie') {
              setCookies.addAll(values);
            }
          });
          if (resp.statusCode != 200) {
            throw StateError('HTTP ${resp.statusCode}');
          }
          final first = body.trimLeft();
          if (first.isEmpty || first[0] != '{') {
            throw StateError(
              '响应不是 JSON：${body.substring(0, body.length > 120 ? 120 : body.length)}',
            );
          }
          return (
            json: jsonDecode(body) as Map<String, dynamic>,
            ts: ts,
            setCookies: setCookies,
          );
        } on Object catch (e) {
          last = e;
          await Future<void>.delayed(
            Duration(milliseconds: 200 * (attempt + 1)),
          );
        }
      }
    }
    throw StateError('JM API 请求失败 $path：$last');
  }

  Future<void> _updateDomains() async {
    for (final url in _domainServers) {
      try {
        final req = await _client.getUrl(Uri.parse(url));
        final resp = await req.close().timeout(const Duration(seconds: 15));
        var text = await utf8.decodeStream(
          resp.timeout(const Duration(seconds: 30)),
        );
        while (text.isNotEmpty && text.codeUnitAt(0) > 127) {
          text = text.substring(1);
        }
        final decoded = JmCrypto.decodeRespData(
          text,
          '',
          secret: JmCrypto.domainServerSecret,
        );
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        final servers = json['Server'];
        if (servers is List && servers.isNotEmpty) {
          _apiDomains = servers.map((e) => e.toString()).toList();
        }
        return;
      } on Object {
        // 尝试下一个域名服务器
      }
    }
  }
}

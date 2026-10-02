import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions.dart';
import '../providers.dart';
import '../auth/biometric_auth.dart';
import '../bucket/bucket_config.dart';
import '../bucket/bucket_init.dart';
import '../library/shelf_page.dart';

/// 桶设置页（M1：录入配置 + 连接测试）。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  static const path = '/settings';

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _endpoint = TextEditingController();
  final _port = TextEditingController();
  final _region = TextEditingController();
  final _bucket = TextEditingController();
  final _ak = TextEditingController();
  final _sk = TextEditingController();
  final _localDir = TextEditingController();
  final _ffmpeg = TextEditingController();
  bool _useSSL = true;
  bool _loaded = false;
  String? _testResult;
  bool? _bioSupported;
  bool _bioEnabled = false;

  /// ffmpeg 只能用于桌面端（AVIF 压缩/下载后转码）；手机端不显示该项。
  static bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _loadLocalDir();
    _loadFfmpeg();
    _loadBiometric();
  }

  Future<void> _loadFfmpeg() async {
    if (!_desktop) return;
    final v = await ref
        .read(settingsRepositoryProvider)
        .get('downloader.ffmpeg');
    if (v != null) _ffmpeg.text = v;
  }

  Future<void> _saveFfmpeg() async {
    await ref
        .read(settingsRepositoryProvider)
        .set('downloader.ffmpeg', _ffmpeg.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存 ffmpeg 路径')));
    }
  }

  Future<void> _loadBiometric() async {
    if (!BiometricAuth.platformSupported) return;
    final bio = ref.read(biometricAuthProvider);
    final supported = await bio.canUnlock();
    if (!mounted) return;
    final enabled = supported
        ? await ref.read(authControllerProvider.notifier).isBiometricEnabled()
        : false;
    if (mounted) {
      setState(() {
        _bioSupported = supported;
        _bioEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    final notifier = ref.read(authControllerProvider.notifier);
    try {
      if (enable) {
        await notifier.enableBiometric();
      } else {
        await notifier.disableBiometric();
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('指纹解锁设置失败: $e')));
      }
      return;
    }
    if (mounted) {
      setState(() => _bioEnabled = enable);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(enable ? '已启用指纹解锁' : '已关闭指纹解锁')));
    }
  }

  Future<void> _loadLocalDir() async {
    final v = await ref
        .read(settingsRepositoryProvider)
        .get('storage.local_dir');
    if (v != null) _localDir.text = v;
  }

  Future<void> _saveLocalDir() async {
    await ref
        .read(settingsRepositoryProvider)
        .set('storage.local_dir', _localDir.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存（对已下载的作品，上传时会自动回退旧目录查找）')),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      _endpoint,
      _port,
      _region,
      _bucket,
      _ak,
      _sk,
      _localDir,
      _ffmpeg,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  BucketConfig _readForm() => BucketConfig(
    endpoint: _endpoint.text.trim(),
    port: int.tryParse(_port.text.trim()),
    useSSL: _useSSL,
    region: _region.text.trim(),
    bucket: _bucket.text.trim(),
    accessKey: _ak.text.trim(),
    secretKey: _sk.text.trim(),
  );

  Future<void> _save({bool navigateAfterSave = true}) async {
    try {
      await ref.read(bucketConfigControllerProvider.notifier).save(_readForm());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存')));
        // 配置就绪后直接去书架；不完整时重定向会把人送回本页
        if (navigateAfterSave) context.go(ShelfPage.path);
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败: ${_classify(e)}')));
      }
    }
  }

  Future<void> _test() async {
    setState(() => _testResult = '测试中…');
    try {
      // 先校验填写项，再落盘，再连通性，最后初始化默认目录
      _readForm().validate();
      await _save(navigateAfterSave: false);
      if (!mounted) return;
      final client = ref.read(bucketClientProvider);
      if (client == null) {
        setState(() => _testResult = '凭证未保存完整（SK 缺失），无法测试');
        return;
      }
      final result = await client.checkConnectivity();
      if (!result.ok) {
        setState(() => _testResult = '连接失败: ${result.detail}');
        return;
      }
      if (!mounted) return;
      setState(() => _testResult = '连接成功 ${result.latencyMs}ms，正在初始化默认目录…');
      final init = await BucketInitializer(client).ensureDefaults();
      if (!mounted) return;
      setState(() {
        final base = '连接成功 ${result.latencyMs}ms';
        _testResult = init.isNoop
            ? '$base，默认目录已存在（works.jsonl / config.json）'
            : '$base，已创建默认对象：${init.created.join('、')}';
      });
    } on Object catch (e) {
      if (mounted) setState(() => _testResult = _classify(e));
    }
  }

  /// 把桶侧错误归类成用户能行动的建议：填错 / 权限 / 连接。
  static String _classify(Object e) {
    final s = e.toString();
    if (e is BucketConfigException) return '填写项有误：${e.message}';
    if (s.contains('NoSuchBucket') || s.contains('bucket 不存在')) {
      return 'Bucket 名称错误或桶不存在：请核对 Bucket 拼写';
    }
    const permHints = [
      'AccessDenied',
      'Access Denied',
      'SignatureDoesNotMatch',
      'InvalidAccessKeyId',
      '403',
    ];
    if (permHints.any(s.contains)) {
      return '权限或凭证错误（缺少权限）：请检查 AK/SK 是否正确、该账号是否有权访问此桶';
    }
    const netHints = [
      'SocketException',
      'TimeoutException',
      'Failed host lookup',
      'HandshakeException',
      'Connection refused',
    ];
    if (netHints.any(s.contains)) {
      return '连接失败：无法连通 Endpoint，请检查地址 / 端口 / SSL 开关或网络';
    }
    return '连接失败：$s';
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(bucketConfigControllerProvider).value;
    if (config != null && !_loaded) {
      _loaded = true;
      _endpoint.text = config.endpoint;
      _port.text = config.port?.toString() ?? '';
      _region.text = config.region;
      _bucket.text = config.bucket;
      _ak.text = config.accessKey;
      // SK 故意不回显（留空 = 不修改）
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('桶设置'),
        actions: [
          IconButton(
            tooltip: '书架',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.go(ShelfPage.path),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _localDir,
            decoration: const InputDecoration(
              labelText: '本地下载目录（漫画页/小说 txt 的存放根；留空 = 文档目录/local_works）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _saveLocalDir,
              child: const Text('保存本地目录'),
            ),
          ),
          if (_desktop) ...[
            const Divider(height: 32),
            TextField(
              controller: _ffmpeg,
              decoration: const InputDecoration(
                labelText: 'ffmpeg 路径（PC 端 AVIF 压缩用）',
                helperText:
                    '到 ffmpeg.org 下载 Windows 构建，解压后填 ffmpeg.exe 的'
                    '绝对路径（如 D:\\tools\\ffmpeg\\bin\\ffmpeg.exe）；'
                    '留空 = 下载/压缩都跳过转码、保留原图，之后可随时补填',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _saveFfmpeg,
                child: const Text('保存 ffmpeg 路径'),
              ),
            ),
          ],
          if (_bioSupported == true) ...[
            const Divider(height: 32),
            SwitchListTile(
              title: const Text('指纹解锁'),
              subtitle: const Text('锁屏时可用指纹/人脸代替 PIN（PIN 变更后自动失效）'),
              value: _bioEnabled,
              onChanged: _toggleBiometric,
            ),
          ],
          const Divider(height: 32),
          TextField(
            controller: _endpoint,
            decoration: const InputDecoration(
              labelText: 'Endpoint（无 scheme，如 oss-cn-hangzhou.aliyuncs.com）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '端口（可空）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('SSL'),
                selected: _useSSL,
                onSelected: (v) => setState(() => _useSSL = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _region,
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bucket,
            decoration: const InputDecoration(
              labelText: 'Bucket',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ak,
            decoration: const InputDecoration(
              labelText: 'AccessKey',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sk,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'SecretKey（留空 = 不修改）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton(onPressed: _save, child: const Text('保存')),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: _test, child: const Text('测试连接')),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Text(_testResult!),
          ],
          const SizedBox(height: 32),
          Text(
            '构建 0929-0710（含缤纷云 204 修复）',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

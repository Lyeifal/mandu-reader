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
import '../library/shelf_query.dart';
import 'directory_picker.dart';
import 'reader_prefs.dart';

/// 设置页：左侧快捷导航分组（存储 / 下载工具 / 阅读 / 书源 / 指纹 / 桶连接），
/// 不再整页平铺；窄屏导航折成顶部横向 chips。
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
  final _jmProxy = TextEditingController();
  bool _useSSL = true;
  bool _loaded = false;
  String? _testResult;
  bool? _bioSupported;
  bool _bioEnabled = false;

  /// 当前选中的设置分组。
  String _section = 'storage';

  /// ffmpeg 只能用于桌面端（AVIF 压缩/下载后转码）；手机端不显示该项。
  static bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _loadLocalDir();
    _loadDownloadTools();
    _loadBiometric();
  }

  Future<void> _loadDownloadTools() async {
    final repo = ref.read(settingsRepositoryProvider);
    final ffmpeg = await repo.get('downloader.ffmpeg');
    final proxy = await repo.get('downloader.jm_proxy');
    if (ffmpeg != null) _ffmpeg.text = ffmpeg;
    if (proxy != null) _jmProxy.text = proxy;
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

  Future<void> _saveJmProxy() async {
    await ref
        .read(settingsRepositoryProvider)
        .set('downloader.jm_proxy', _jmProxy.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存 JM 代理')));
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

  /// 应用内目录选择器取代手输：手机端无法合理要求输入绝对路径。
  Future<void> _pickLocalDir() async {
    final picked = await DirectoryPickerDialog.show(context);
    if (picked == null || !mounted) return;
    await ref.read(settingsRepositoryProvider).set('storage.local_dir', picked);
    ref.invalidate(localRootProvider);
    setState(() => _localDir.text = picked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存（已下载的作品仍在原目录，上传时会自动回退查找）')),
      );
    }
  }

  Future<void> _resetLocalDir() async {
    await ref.read(settingsRepositoryProvider).set('storage.local_dir', '');
    ref.invalidate(localRootProvider);
    setState(() => _localDir.clear());
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
      _jmProxy,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ 分组内容

  List<Widget> _storageBlocks(ThemeData theme) => [
    Text('本地下载目录', style: theme.textTheme.titleSmall),
    const SizedBox(height: 6),
    Text(
      _localDir.text.isEmpty ? '默认：应用文档目录/local_works' : _localDir.text,
      style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          onPressed: _pickLocalDir,
          icon: const Icon(Icons.folder_open),
          label: const Text('选择目录'),
        ),
        if (_localDir.text.isNotEmpty)
          OutlinedButton(onPressed: _resetLocalDir, child: const Text('恢复默认')),
      ],
    ),
    const SizedBox(height: 4),
    Text(
      'Android 仅能选择应用私有目录（系统存储限制）；更改只影响新下载',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    ),
  ];

  List<Widget> _downloadBlocks(ThemeData theme) => [
    TextField(
      controller: _jmProxy,
      decoration: const InputDecoration(
        labelText: 'JM 下载代理（留空 = 直连）',
        hintText: 'http://127.0.0.1:7897',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _saveJmProxy(),
    ),
    const SizedBox(height: 4),
    Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: _saveJmProxy,
        child: const Text('保存 JM 代理'),
      ),
    ),
    if (_desktop) ...[
      const SizedBox(height: 16),
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
    ] else ...[
      const SizedBox(height: 8),
      Text(
        '手机端无法执行外部二进制：下载保留原图，AVIF 压缩由桌面端/云端 Worker 完成',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    ],
  ];

  List<Widget> _bucketBlocks() => [
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
  ];

  // ------------------------------------------------------------ 桶逻辑（原样保留）

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

  // ------------------------------------------------------------ 导航

  static const _navItems = [
    (key: 'storage', label: '本地下载目录', icon: Icons.folder_outlined),
    (key: 'download', label: '下载工具', icon: Icons.download_outlined),
    (key: 'reading', label: '阅读设置', icon: Icons.menu_book_outlined),
    (key: 'source', label: '书源', icon: Icons.travel_explore),
    (key: 'security', label: '指纹解锁', icon: Icons.fingerprint),
    (key: 'bucket', label: '桶连接', icon: Icons.cloud_outlined),
  ];

  List<Widget> _sectionBlocks(ThemeData theme) => switch (_section) {
    'storage' => _storageBlocks(theme),
    'download' => _downloadBlocks(theme),
    'reading' => const [ReadingPrefsSection()],
    'source' => const [SourcePrefsSection()],
    'security' => [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('指纹解锁'),
        subtitle: const Text('锁屏时可用指纹/人脸代替 PIN（PIN 变更后自动失效）'),
        value: _bioEnabled,
        onChanged: _toggleBiometric,
      ),
    ],
    _ => _bucketBlocks(),
  };

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

    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final items = [
      for (final it in _navItems)
        if (it.key != 'security' || _bioSupported == true) it,
    ];

    Widget navTile((String, String, IconData) it) {
      final (key, label, icon) = it;
      final selected = _section == key;
      return ListTile(
        dense: true,
        leading: Icon(icon, size: 20),
        title: Text(label, maxLines: 1, style: const TextStyle(fontSize: 13)),
        selected: selected,
        onTap: () => setState(() => _section = key),
      );
    }

    final content = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ..._sectionBlocks(theme),
        const SizedBox(height: 32),
        Text(
          '构建 0929-0710（含缤纷云 204 修复）',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        // 设置已多分组，不再叫「桶设置」
        title: const Text('设置'),
        actions: [
          IconButton(
            tooltip: '书架',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.go(ShelfPage.path),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!wide)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(it.icon, size: 16),
                        label: Text(it.label),
                        showCheckmark: false,
                        selected: _section == it.key,
                        onSelected: (_) => setState(() => _section = it.key),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                if (wide) ...[
                  SizedBox(
                    width: 188,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final it in items)
                          navTile((it.key, it.label, it.icon)),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

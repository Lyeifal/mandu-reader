import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../bucket/bucket_config.dart';

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
  bool _useSSL = true;
  bool _loaded = false;
  String? _testResult;

  @override
  void dispose() {
    for (final c in [_endpoint, _port, _region, _bucket, _ak, _sk]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final config = BucketConfig(
      endpoint: _endpoint.text.trim(),
      port: int.tryParse(_port.text.trim()),
      useSSL: _useSSL,
      region: _region.text.trim(),
      bucket: _bucket.text.trim(),
      accessKey: _ak.text.trim(),
      secretKey: _sk.text.trim(),
    );
    try {
      await ref.read(bucketConfigControllerProvider.notifier).save(config);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存')));
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  Future<void> _test() async {
    setState(() => _testResult = '测试中…');
    try {
      await _save();
      final client = ref.read(bucketClientProvider);
      if (client == null) {
        setState(() => _testResult = '客户端不可用：请先填写并保存完整凭证');
        return;
      }
      final result = await client.checkConnectivity();
      setState(
        () => _testResult = result.ok
            ? '连接成功 ${result.latencyMs}ms，index etag=${result.indexEtag ?? '（无 _index 对象）'}'
            : '连接失败: ${result.detail}',
      );
    } on Object catch (e) {
      setState(() => _testResult = '连接失败: $e');
    }
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
      appBar: AppBar(title: const Text('桶设置')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
        ],
      ),
    );
  }
}

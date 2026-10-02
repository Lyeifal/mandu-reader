import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'jm_models.dart';
import 'jm_tasks.dart';

/// JM 相册下载入口：提交后进后台任务列表，弹窗立即关闭。
class JmDownloadDialog extends ConsumerStatefulWidget {
  const JmDownloadDialog({super.key});

  @override
  ConsumerState<JmDownloadDialog> createState() => _JmDownloadDialogState();
}

class _JmDownloadDialogState extends ConsumerState<JmDownloadDialog> {
  final _id = TextEditingController();
  // ffmpeg 路径不写死：每台机器自己填（设置按设备本机存储，不跨设备同步）；
  // 留空 = 跳过压缩保留原图，之后可在 PC 端「压缩云端漫画」兜底。
  final _ffmpeg = TextEditingController();
  final _proxy = TextEditingController(text: 'http://127.0.0.1:7897');

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final repo = ref.read(settingsRepositoryProvider);
    final ffmpeg = await repo.get('downloader.ffmpeg');
    final proxy = await repo.get('downloader.jm_proxy');
    if (ffmpeg != null && ffmpeg.isNotEmpty) _ffmpeg.text = ffmpeg;
    if (proxy != null) _proxy.text = proxy;
  }

  @override
  void dispose() {
    for (final c in [_id, _ffmpeg, _proxy]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final albumId = parseJmAlbumId(_id.text);
    if (albumId == null) {
      _toast('请输入有效的 JM 车号或链接（至少 4 位数字）');
      return;
    }
    // 提前取 container：后续有 await，不能跨异步间隙用 context
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.set('downloader.ffmpeg', _ffmpeg.text.trim());
    await repo.set('downloader.jm_proxy', _proxy.text.trim());

    final ffmpeg = _ffmpeg.text.trim();
    final proxy = _proxy.text.trim();
    unawaited(
      startJmDownload(
        container,
        albumId: albumId,
        ffmpegPath: ffmpeg,
        proxy: proxy,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
      _toast('已加入下载任务；下载完即可阅读，右上角任务列表可看进度');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('JM 下载'),
      content: SizedBox(
        width: 440,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _id,
              decoration: const InputDecoration(
                labelText: '车号 / 链接',
                hintText: '如 123456 或 https://18comic.org/album/123456/',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ffmpeg,
              decoration: const InputDecoration(
                labelText: 'ffmpeg 路径（本机填写；留空 = 不压缩保留原图）',
                hintText:
                    r'PC 端填 ffmpeg.exe 绝对路径，如 D:\tools\ffmpeg\bin\ffmpeg.exe',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _proxy,
              decoration: const InputDecoration(
                labelText: '代理（留空直连）',
                hintText: 'http://127.0.0.1:7897',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.download),
          label: const Text('下载'),
        ),
      ],
    );
  }
}

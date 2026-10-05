import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'jm_models.dart';
import 'jm_tasks.dart';

/// JM 相册下载入口：提交后进后台任务列表，弹窗立即关闭。
/// ffmpeg / 代理不再在此填写——统一在设置页「下载」分组配置，
/// 提交时从设置读取（见 settings_page.dart）。
class JmDownloadDialog extends ConsumerStatefulWidget {
  const JmDownloadDialog({super.key});

  @override
  ConsumerState<JmDownloadDialog> createState() => _JmDownloadDialogState();
}

class _JmDownloadDialogState extends ConsumerState<JmDownloadDialog> {
  final _id = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
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
    final ffmpeg = (await repo.get('downloader.ffmpeg'))?.trim() ?? '';
    final proxy = (await repo.get('downloader.jm_proxy'))?.trim() ?? '';

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
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '车号 / 链接',
                hintText: '如 123456 或 https://18comic.org/album/123456/',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Text(
              'ffmpeg 与代理在「设置 → 下载」中配置',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
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

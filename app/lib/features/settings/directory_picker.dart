import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用内目录选择器：替代手输路径（手机端无法合理要求用户输入绝对路径）。
///
/// 平台差异（硬约束）：
/// - Android 只列应用私有目录——SAF 返回的 content:// 路径无法被 dart:io
///   使用，而公共目录在 Android 10+ 禁止直接文件 IO；
/// - 桌面端从 home / 盘符根自由浏览，dart:io 全权可用。
class DirectoryPickerDialog extends StatefulWidget {
  const DirectoryPickerDialog({super.key});

  /// 弹出选择器，返回选中的目录绝对路径；取消返回 null。
  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const DirectoryPickerDialog(),
  );

  @override
  State<DirectoryPickerDialog> createState() => _DirectoryPickerDialogState();
}

/// 平台相关根目录列表（目录/文件选择器共用）。
Future<List<Directory>> deviceRoots() async {
  if (Platform.isAndroid) {
    // 仅应用私有目录可直接 dart:io 读写（SAF content:// 不适用）
    final roots = <Directory>[];
    final docs = await getApplicationDocumentsDirectory();
    roots.add(docs);
    // 内置/外置/SD 卡的应用专属目录（系统授权外不可写，故不列公共目录）
    final extDirs = await getExternalStorageDirectories();
    if (extDirs != null) {
      for (final d in extDirs) {
        if (!roots.any((r) => r.path == d.path)) roots.add(d);
      }
    }
    return roots;
  }
  final roots = <Directory>[];
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.isNotEmpty && await Directory(home).exists()) {
    roots.add(Directory(home));
  }
  if (Platform.isWindows) {
    // 所有可用盘符
    for (var c = 67; c <= 90; c++) {
      final drive = Directory('${String.fromCharCode(c)}:\\');
      if (await drive.exists() &&
          !roots.any((r) => r.path.toLowerCase() == drive.path.toLowerCase())) {
        roots.add(drive);
      }
    }
  } else {
    roots.add(Directory('/'));
  }
  return roots;
}

class _DirectoryPickerDialogState extends State<DirectoryPickerDialog> {
  /// 导航栈：最后一个为当前目录；栈底为虚拟「根列表」（path = ''）。
  final List<Directory> _stack = [];

  List<FileSystemEntity> _entries = [];
  bool _loading = true;

  bool get _atRootList => _stack.isEmpty;
  Directory get _current => _stack.last;

  @override
  void initState() {
    super.initState();
    _openRootList();
  }

  Future<void> _openRootList() async {
    setState(() {
      _stack.clear();
      _loading = true;
    });
    final roots = await _deviceRoots();
    setState(() {
      _entries = roots.cast<FileSystemEntity>();
      _loading = false;
    });
  }

  Future<void> _open(Directory dir) async {
    setState(() => _loading = true);
    try {
      final children = await dir
          .list()
          .where((e) => e is Directory && !p.basename(e.path).startsWith('.'))
          .toList();
      children.sort(
        (a, b) => p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _stack.add(dir);
        _entries = children;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('无法打开目录：$e')));
    }
  }

  void _up() {
    if (_stack.isEmpty) return;
    final parent = _current.parent;
    // 到设备根（parent 与自身相同）则回根列表
    if (parent.path == _current.path) {
      _openRootList();
    } else {
      _open(parent);
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('新建文件夹'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) return;
    if (!RegExp(r'^[^\\/:*?"<>|]+$').hasMatch(name)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('文件夹名含有非法字符')));
      return;
    }
    try {
      final dir = Directory(p.join(_current.path, name));
      await dir.create();
      await _open(_current);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败：$e')));
    }
  }

  /// 平台相关根目录列表。
  Future<List<Directory>> _deviceRoots() => deviceRoots();

  String get _title =>
      _atRootList ? '选择保存目录' : (_current.path.isEmpty ? '根目录' : _current.path);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 480,
        height: 380,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _entries.isEmpty
                        ? const Center(child: Text('没有可进入的目录'))
                        : ListView.builder(
                            itemCount: _entries.length + (_atRootList ? 0 : 1),
                            itemBuilder: (context, i) {
                              if (!_atRootList && i == 0) {
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.arrow_upward),
                                  title: const Text('..'),
                                  onTap: _up,
                                );
                              }
                              final dir = _entries[i - (_atRootList ? 0 : 1)];
                              final name = _atRootList
                                  ? _rootLabel(dir.path)
                                  : p.basename(dir.path);
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.folder_outlined),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: _atRootList
                                    ? Text(
                                        dir.path,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      )
                                    : null,
                                onTap: () => _open(Directory(dir.path)),
                              );
                            },
                          ),
                  ),
                  if (!_atRootList)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('新建文件夹'),
                        onPressed: _createFolder,
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
        if (!_atRootList)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_current.path),
            child: const Text('使用此目录'),
          ),
      ],
    );
  }

  /// 根列表条目的友好名（Android 应用目录路径长，给个体面的名字）。
  String _rootLabel(String path) {
    if (Platform.isAndroid) {
      if (path.contains('/storage/emulated') || path.endsWith('app_flutter')) {
        return '内置存储 · 应用文档（默认）';
      }
      if (path.contains('Android/data')) return '外置存储 · 应用目录';
      return '存储卡 · 应用目录';
    }
    return path;
  }
}

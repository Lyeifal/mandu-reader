import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// 简易文件浏览器：浏览目录、多选 .epub / 单选 .txt，返回选中的文件路径。
/// 无第三方依赖（桌面端没有内建文件选择器）。
Future<List<String>?> showNovelPicker(
  BuildContext context, {
  required String initialDir,
}) => showDialog<List<String>>(
  context: context,
  builder: (context) => NovelPickerDialog(initialDir: initialDir),
);

class NovelPickerDialog extends StatefulWidget {
  const NovelPickerDialog({super.key, required this.initialDir});

  final String initialDir;

  @override
  State<NovelPickerDialog> createState() => _NovelPickerDialogState();
}

class _NovelPickerDialogState extends State<NovelPickerDialog> {
  late String _dir;
  final _pathInput = TextEditingController();
  List<FileSystemEntity> _entries = const [];
  String? _error;
  final Set<String> _selected = {};

  static const _exts = {'.epub', '.txt'};

  @override
  void initState() {
    super.initState();
    _dir = widget.initialDir;
    _pathInput.text = _dir;
    _reload();
  }

  @override
  void dispose() {
    _pathInput.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _error = null;
      _entries = const [];
    });
    try {
      final dir = Directory(_dir);
      if (!await dir.exists()) {
        setState(() => _error = '目录不存在：$_dir');
        return;
      }
      final all = await dir.list().toList();
      final dirs = all.whereType<Directory>().toList()
        ..sort(
          (a, b) => p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase()),
        );
      final files =
          all
              .whereType<File>()
              .where((f) => _exts.contains(p.extension(f.path).toLowerCase()))
              .toList()
            ..sort(
              (a, b) => p
                  .basename(a.path)
                  .toLowerCase()
                  .compareTo(p.basename(b.path).toLowerCase()),
            );
      if (!mounted) return;
      setState(() => _entries = [...dirs, ...files]);
    } on Object catch (e) {
      setState(() => _error = '读取失败：$e');
    }
  }

  void _enter(String dir) {
    setState(() {
      _dir = dir;
      _pathInput.text = dir;
      _selected.clear();
    });
    _reload();
  }

  void _up() {
    final parent = p.dirname(_dir);
    if (parent != _dir) _enter(parent);
  }

  void _toggle(File f) {
    final isTxt = f.path.toLowerCase().endsWith('.txt');
    setState(() {
      if (isTxt) {
        // txt 单选：重复点同一个是取消
        if (_selected.contains(f.path)) {
          _selected.remove(f.path);
        } else {
          _selected
            ..clear()
            ..add(f.path);
        }
      } else if (!_selected.remove(f.path)) {
        _selected.add(f.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          IconButton(
            tooltip: '上一级',
            icon: const Icon(Icons.arrow_upward),
            onPressed: _up,
          ),
          Expanded(
            child: TextField(
              controller: _pathInput,
              decoration: const InputDecoration(
                hintText: '输入目录后回车',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => _enter(v.trim()),
            ),
          ),
          IconButton(
            tooltip: '进入',
            icon: const Icon(Icons.keyboard_return),
            onPressed: () => _enter(_pathInput.text.trim()),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 420,
        child: _error != null
            ? Center(child: Text(_error!))
            : _entries.isEmpty
            ? const Center(child: Text('此目录没有小说文件'))
            : ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (context, i) {
                  final e = _entries[i];
                  if (e is Directory) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.folder),
                      title: Text(p.basename(e.path)),
                      onTap: () => _enter(e.path),
                    );
                  }
                  final file = e as File;
                  final path = file.path;
                  final name = p.basename(path);
                  return ListTile(
                    dense: true,
                    leading: Checkbox(
                      value: _selected.contains(path),
                      onChanged: (_) => _toggle(file),
                    ),
                    title: Text(name),
                    subtitle: name.toLowerCase().endsWith('.txt')
                        ? const Text('txt 仅单选')
                        : null,
                    onTap: () => _toggle(file),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
          child: Text('导入 ${_selected.length} 个'),
        ),
      ],
    );
  }
}

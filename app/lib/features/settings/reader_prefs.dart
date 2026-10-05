import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../providers.dart';
import '../reader/font_sync.dart';
import '../reader/reader_page.dart';
import 'directory_picker.dart';

/// 通用文件选择对话框（仿目录选择器，桌面端专用）。
/// 目录栈浏览 + 扩展名过滤，点文件即选中返回；Android 无法使用
/// （SAF content:// 无法被 dart:io 读取），调用方自行按平台隐藏入口。
class FilePickerDialog extends StatefulWidget {
  const FilePickerDialog({super.key, required this.extensions});

  /// 允许的扩展名（小写、带点，如 {'.ttf'}）；空集 = 不过滤。
  final Set<String> extensions;

  /// 弹出选择器，返回选中的文件绝对路径；取消返回 null。
  static Future<String?> show(
    BuildContext context, {
    required String title,
    Set<String> extensions = const {},
  }) => showDialog<String>(
    context: context,
    builder: (_) => FilePickerDialog(extensions: extensions),
  );

  @override
  State<FilePickerDialog> createState() => _FilePickerDialogState();
}

class _FilePickerDialogState extends State<FilePickerDialog> {
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
    final roots = await deviceRoots();
    setState(() {
      _entries = roots.cast<FileSystemEntity>();
      _loading = false;
    });
  }

  bool _accepts(File f) =>
      widget.extensions.isEmpty ||
      widget.extensions.contains(p.extension(f.path).toLowerCase());

  Future<void> _open(Directory dir) async {
    setState(() => _loading = true);
    try {
      final children = await dir
          .list()
          .where(
            (e) =>
                (e is Directory && !p.basename(e.path).startsWith('.')) ||
                (e is File && _accepts(e)),
          )
          .toList();
      children.sort((a, b) {
        // 目录在前，文件在后；同级按名排序
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });
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
    if (parent.path == _current.path) {
      _openRootList();
    } else {
      _open(parent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _atRootList ? '选择文件' : _current.path,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 480,
        height: 380,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
            ? const Center(child: Text('没有可选择的文件'))
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
                  final e = _entries[i - (_atRootList ? 0 : 1)];
                  if (e is Directory) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(
                        p.basename(e.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _open(Directory(e.path)),
                    );
                  }
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      p.basename(e.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(e.path),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 色盘常用色（亮色/暗色/纸质系搭配够用）。
const _palette = [
  Color(0xFFFFFFFF),
  Color(0xFFFCFCFA),
  Color(0xFFF5F0E1),
  Color(0xFFC7EDCC),
  Color(0xFFFFF2CC),
  Color(0xFFE8F4F8),
  Color(0xFFD8CAB8),
  Color(0xFFB8BDC7),
  Color(0xFF6B7B8C),
  Color(0xFF4A4234),
  Color(0xFF3A4A3C),
  Color(0xFF2A2A2A),
  Color(0xFF2D3748),
  Color(0xFF111318),
  Color(0xFF000000),
];

/// 颜色选择对话框：色盘点选 + 十六进制输入 + 预览；取消返回 null。
Future<Color?> showColorPickDialog(
  BuildContext context, {
  required Color initial,
  required String title,
}) => showDialog<Color>(
  context: context,
  builder: (_) => _ColorPickDialog(initial: initial, title: title),
);

class _ColorPickDialog extends StatefulWidget {
  const _ColorPickDialog({required this.initial, required this.title});

  final Color initial;
  final String title;

  @override
  State<_ColorPickDialog> createState() => _ColorPickDialogState();
}

class _ColorPickDialogState extends State<_ColorPickDialog> {
  late Color _color = widget.initial;
  final _hex = TextEditingController();
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _hex.text = formatHexColor(widget.initial);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _applyHex(String v) {
    final c = parseHexColor(v);
    if (c == null) {
      setState(() => _hexError = '格式应为 #RRGGBB');
      return;
    }
    setState(() {
      _color = c;
      _hexError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _palette)
                InkWell(
                  onTap: () {
                    setState(() => _color = c);
                    _hex.text = formatHexColor(c);
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == _color
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black26,
                        width: c == _color ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hex,
            maxLength: 7,
            onSubmitted: _applyHex,
            decoration: InputDecoration(
              labelText: '十六进制（#RRGGBB）',
              errorText: _hexError,
              counterText: '',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black26),
            ),
            alignment: Alignment.center,
            child: Text(
              formatHexColor(_color),
              style: TextStyle(
                color:
                    ThemeData.estimateBrightnessForColor(_color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            _applyHex(_hex.text);
            if (_hexError == null) Navigator.of(context).pop(_color);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 设置页「阅读设置」组：护眼自定义色 / 定时切换 / 背景图片。
/// 字体导入在同文件 M4-b 追加（fontFamily 键已在 settings_repository defaults）。
class ReadingPrefsSection extends ConsumerStatefulWidget {
  const ReadingPrefsSection({super.key});

  @override
  ConsumerState<ReadingPrefsSection> createState() =>
      _ReadingPrefsSectionState();
}

class _ReadingPrefsSectionState extends ConsumerState<ReadingPrefsSection> {
  /// 背景图/字体导入仅桌面端可选（Android 无法读取外部文件，见 directory_picker 注）。
  static bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static const _presetLabels = {
    'day': '白天',
    'eyecare': '护眼',
    'parchment': '羊皮纸',
    'night': '夜间',
  };

  String _customBg = '#FCFCFA';
  String _customFg = '#2A2A2A';
  String _schedule = 'off';
  String _night = 'night';
  final _start = TextEditingController();
  final _end = TextEditingController();
  String _bgImage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final customBg = await repo.get('reader.novel.customBg');
    final customFg = await repo.get('reader.novel.customFg');
    final schedule = await repo.get('reader.novel.themeSchedule');
    final night = await repo.get('reader.novel.themeScheduleNightPreset');
    final start = await repo.get('reader.novel.themeScheduleStart');
    final end = await repo.get('reader.novel.themeScheduleEnd');
    final bg = await repo.get('reader.novel.bgImage');
    if (!mounted) return;
    setState(() {
      _customBg = customBg ?? _customBg;
      _customFg = customFg ?? _customFg;
      if (schedule == 'off' || schedule == 'system' || schedule == 'time') {
        _schedule = schedule!;
      }
      if (_presetLabels.containsKey(night)) _night = night!;
      _start.text = start ?? _start.text;
      _end.text = end ?? _end.text;
      _bgImage = bg ?? '';
    });
  }

  Future<void> _save(String key, String value) =>
      ref.read(settingsRepositoryProvider).set(key, value);

  Future<void> _pickColor(String key, String current, String title) async {
    final base = parseHexColor(current) ?? const Color(0xFFFCFCFA);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showColorPickDialog(
      context,
      initial: base,
      title: title,
    );
    if (picked == null || !mounted) return;
    final hex = formatHexColor(picked);
    await _save(key, hex);
    setState(() {
      if (key == 'reader.novel.customBg') {
        _customBg = hex;
      } else {
        _customFg = hex;
      }
    });
    messenger.showSnackBar(SnackBar(content: Text('$title已保存：$hex')));
  }

  Future<void> _saveTime(String key, TextEditingController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final v = c.text.trim();
    if (parseHm(v) == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('时间格式应为 HH:mm（如 20:00）')),
      );
      return;
    }
    await _save(key, v);
  }

  Future<void> _pickBgImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePickerDialog.show(
      context,
      title: '选择背景图片',
      extensions: const {'.jpg', '.jpeg', '.png', '.webp', '.avif'},
    );
    if (picked == null || !mounted) return;
    try {
      // 复制到应用私有目录：原文件被移动/删除不影响阅读；重名自动加后缀
      final dir = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'reader_bg'),
      );
      await dir.create(recursive: true);
      final ext = p.extension(picked).toLowerCase();
      final stem = p.basenameWithoutExtension(picked);
      var name = '$stem$ext';
      var target = File(p.join(dir.path, name));
      for (var n = 2; await target.exists(); n++) {
        name = '${stem}_$n$ext';
        target = File(p.join(dir.path, name));
      }
      await File(picked).copy(target.path);
      await _save('reader.novel.bgImage', target.path);
      setState(() => _bgImage = target.path);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('设置背景图失败：$e')));
    }
  }

  Future<void> _clearBgImage() async {
    await _save('reader.novel.bgImage', '');
    setState(() => _bgImage = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    Widget swatch(String label, String key, String current) => Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        GestureDetector(
          onTap: () => _pickColor(key, current, label),
          child: Container(
            width: 40,
            height: 28,
            decoration: BoxDecoration(
              color: parseHexColor(current) ?? Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: outline),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          current,
          style: theme.textTheme.bodySmall?.copyWith(color: outline),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('小说阅读', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          '自定义颜色（阅读器主题选「自定义」时生效）',
          style: theme.textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        swatch('背景色', 'reader.novel.customBg', _customBg),
        const SizedBox(height: 8),
        swatch('文字色', 'reader.novel.customFg', _customFg),
        const SizedBox(height: 16),
        Text('定时切换主题', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'off', label: Text('关')),
            ButtonSegment(value: 'system', label: Text('系统')),
            ButtonSegment(value: 'time', label: Text('时段')),
          ],
          selected: {_schedule},
          showSelectedIcon: false,
          onSelectionChanged: (v) {
            setState(() => _schedule = v.first);
            _save('reader.novel.themeSchedule', v.first);
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('夜间用', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _night,
              items: [
                for (final e in _presetLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _night = v);
                _save('reader.novel.themeScheduleNightPreset', v);
              },
            ),
          ],
        ),
        if (_schedule == 'time') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _start,
                  decoration: const InputDecoration(
                    labelText: '开始（HH:mm）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) =>
                      _saveTime('reader.novel.themeScheduleStart', _start),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _end,
                  decoration: const InputDecoration(
                    labelText: '结束（HH:mm）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) =>
                      _saveTime('reader.novel.themeScheduleEnd', _end),
                ),
              ),
            ],
          ),
        ],
        Text(
          _schedule == 'off'
              ? '到点自动切换；时段外恢复手动选择的主题'
              : _schedule == 'system'
              ? '系统深色模式开启时使用夜间主题'
              : '时段内使用夜间主题，支持跨零点（如 20:00–07:00）',
          style: theme.textTheme.bodySmall?.copyWith(color: outline),
        ),
        if (_desktop) ...[
          const SizedBox(height: 16),
          Text('背景图片', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            _bgImage.isEmpty ? '未设置（纯色背景）' : p.basename(_bgImage),
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: _pickBgImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('选择图片'),
              ),
              if (_bgImage.isNotEmpty)
                OutlinedButton(
                  onPressed: _clearBgImage,
                  child: const Text('清除'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _FontSection(desktop: _desktop),
      ],
    );
  }
}

/// 书源设置组（M5）：代理 / 并发 / 抓章重试。
class SourcePrefsSection extends ConsumerStatefulWidget {
  const SourcePrefsSection({super.key});

  @override
  ConsumerState<SourcePrefsSection> createState() => _SourcePrefsSectionState();
}

class _SourcePrefsSectionState extends ConsumerState<SourcePrefsSection> {
  final _proxy = TextEditingController();
  bool _proxyAll = false;
  int _concurrency = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _proxy.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final proxy = await repo.get('source.proxy');
    final all = await repo.get('source.proxy_all');
    final c = int.tryParse(await repo.get('source.concurrency') ?? '3') ?? 3;
    if (!mounted) return;
    setState(() {
      _proxy.text = proxy ?? '';
      _proxyAll = all == 'true';
      _concurrency = c.clamp(1, 4);
    });
  }

  Future<void> _save(String key, String value) =>
      ref.read(settingsRepositoryProvider).set(key, value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('书源', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: _proxy,
          decoration: const InputDecoration(
            labelText: '书源 HTTP 代理（仅 needProxy 源使用）',
            helperText: '格式 host:port；留空 = 全部直连（与 JM 代理互不影响）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) => _save('source.proxy', v.trim()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('全部书源走代理'),
          value: _proxyAll,
          onChanged: (v) {
            setState(() => _proxyAll = v);
            _save('source.proxy_all', '$v');
          },
        ),
        Row(
          children: [
            Text('并发', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {_concurrency},
              showSelectedIcon: false,
              onSelectionChanged: (v) {
                setState(() => _concurrency = v.first);
                _save('source.concurrency', '${v.first}');
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '书源规则派生自 so-novel（AGPL-3.0），致谢见 assets/rules/NOTICE.md',
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 字体库设置组（M4-b）：列表全平台可见（Android 经桶同步获得字体），
/// 导入仅桌面端（SAF content:// 无法被 dart:io 读取）。
class _FontSection extends ConsumerStatefulWidget {
  const _FontSection({required this.desktop});

  final bool desktop;

  @override
  ConsumerState<_FontSection> createState() => _FontSectionState();
}

class _FontSectionState extends ConsumerState<_FontSection> {
  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePickerDialog.show(
      context,
      title: '选择字体文件（.ttf / .otf）',
      extensions: const {'.ttf', '.otf'},
    );
    if (picked == null || !mounted) return;
    try {
      await ref.read(fontLibraryProvider.notifier).importFont(picked);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('已导入并同步到桶（其它设备进入阅读器后自动下载）')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导入字体失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final fonts = ref.watch(fontLibraryProvider).value ?? const <FontEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('字体', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          '字体库：${fonts.length} 个（桶内 library/_fonts/ 自动同步，跨设备可用）',
          style: theme.textTheme.bodySmall?.copyWith(color: outline),
        ),
        if (fonts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final f in fonts)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    f.fileName,
                    style: TextStyle(fontFamily: f.family),
                  ),
                ),
            ],
          ),
        ],
        if (widget.desktop) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _import,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('导入字体…'),
          ),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            'Android 无法读取本地字体文件：请在桌面端导入，经桶同步到本机',
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
        ],
      ],
    );
  }
}

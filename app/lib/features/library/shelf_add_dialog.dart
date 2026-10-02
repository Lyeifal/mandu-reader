import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/db/app_database.dart';
import '../downloader/jm_pipeline.dart' show resolveLocalRoot;
import '../providers.dart';
import 'epub_import.dart';
import 'novel_picker_dialog.dart';
import 'shelf_filter_panel.dart' show showMonthPicker, statusLabel;
import 'shelf_query.dart';

/// 手动添加入口（本地登记，local_only）：上传漫画/小说时在此录入元数据。
/// 归档到桶走设计文档 §8.3「上传归档」流程（M6），本入口不直接写桶索引。
class AddWorkDialog extends ConsumerStatefulWidget {
  const AddWorkDialog({super.key, required this.initialType});

  /// 打开弹窗时书架所在页签（漫画/小说）。
  final String initialType;

  @override
  ConsumerState<AddWorkDialog> createState() => _AddWorkDialogState();
}

class _AddWorkDialogState extends ConsumerState<AddWorkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _titleJp = TextEditingController();
  final _author = TextEditingController();
  final _tags = TextEditingController();
  final _filePath = TextEditingController();

  late String _type;
  String _status = 'completed';
  late String _publishedAt;
  String _completedAt = '';
  bool _saving = false;

  /// 上传当月（YYYY-MM）：作为默认发布/完结时间。
  static String get _thisMonth {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    // 默认完结：上传时间即发布时间，也是完结时间
    _publishedAt = _thisMonth;
    _completedAt = _thisMonth;
  }

  @override
  void dispose() {
    for (final c in [_title, _titleJp, _author, _tags, _filePath]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _tagList => _tags.text
      .split(RegExp(r'[,，、\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _pick(bool isPublished) async {
    final picked = await showMonthPicker(
      context: context,
      initial: isPublished
          ? (_publishedAt.isEmpty ? null : _publishedAt)
          : (_completedAt.isEmpty ? null : _completedAt),
    );
    if (picked == null) return;
    setState(() {
      if (isPublished) {
        _publishedAt = picked;
      } else {
        _completedAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final id = '${_type}_${DateTime.now().millisecondsSinceEpoch}';
    var fileWarning = '';
    var coverFile = '';
    var parsedTitle = '';
    var parsedAuthor = '';
    String? parsedMonth;
    try {
      final srcPath = _filePath.text.trim();
      if (srcPath.isNotEmpty) {
        final src = File(srcPath);
        if (await src.exists()) {
          final root = await resolveLocalRoot(
            ref.read(settingsRepositoryProvider),
          );
          final dstDir = Directory(p.join(root, id));
          await dstDir.create(recursive: true);
          if (_type == 'novel' && srcPath.toLowerCase().endsWith('.epub')) {
            // epub：解析元数据 + 章节转纯文本 + 封面/章节表落盘
            final novel = await importEpub(await src.readAsBytes());
            if (novel.text.isEmpty) {
              throw const FormatException('epub 中没有可读文本');
            }
            await File(p.join(dstDir.path, 'book.txt'))
                .writeAsString(novel.text);
            if (novel.coverJpg != null) {
              await File(p.join(dstDir.path, 'cover.jpg'))
                  .writeAsBytes(novel.coverJpg!);
              coverFile = 'cover.jpg';
            }
            await File(p.join(dstDir.path, 'chapters.json')).writeAsString(
              jsonEncode([
                for (final c in novel.chapters)
                  {'title': c.title, 'para': c.para},
              ]),
            );
            parsedTitle = novel.title;
            parsedAuthor = novel.author;
            parsedMonth = novel.publishedMonth;
          } else if (_type == 'novel') {
            await src.copy(p.join(dstDir.path, 'book.txt'));
          } else {
            fileWarning = '漫画请先把图片放入本地目录，这里仅登记元数据';
          }
        } else {
          fileWarning = '本地文件不存在，仅登记元数据';
        }
      }
      final db = ref.read(appDatabaseProvider);
      final today = DateTime.now();
      await db
          .into(db.works)
          .insert(
            WorksCompanion(
              id: Value(id),
              type: Value(_type),
              // epub 解析出的书名/作者仅在用户未手填时补入
              title: Value(
                _title.text.trim().isNotEmpty
                    ? _title.text.trim()
                    : parsedTitle,
              ),
              titleJp: Value(_titleJp.text.trim()),
              author: Value(
                _author.text.trim().isNotEmpty
                    ? _author.text.trim()
                    : parsedAuthor,
              ),
              status: Value(_status),
              tags: Value(jsonEncode(_tagList)),
              // 时间规则：手填优先；未填时用 epub 的 dc:date，再没有才留空
              publishedAt: Value(
                _publishedAt.isEmpty ? parsedMonth : _publishedAt,
              ),
              completedAt: Value(_completedAt.isEmpty ? null : _completedAt),
              lastUpdated: Value(
                '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
              ),
              cover: Value(coverFile),
              localOnly: const Value(true),
              origin: const Value('manual'),
              syncedAt: Value(DateTime.now()),
            ),
          );
      ref
        ..invalidate(shelfWorksProvider)
        ..invalidate(shelfTotalProvider)
        ..invalidate(shelfTagsProvider)
        ..invalidate(shelfStatusesProvider)
        ..invalidate(shelfAuthorsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fileWarning.isEmpty ? '已添加' : fileWarning)),
      );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _refreshShelf() {
    ref
      ..invalidate(shelfWorksProvider)
      ..invalidate(shelfTotalProvider)
      ..invalidate(shelfTagsProvider)
      ..invalidate(shelfStatusesProvider)
      ..invalidate(shelfAuthorsProvider);
  }

  /// 导入单个 epub 为本地作品（浏览多选批量导入用）：
  /// 元数据/封面自动带出，时间按「上传当月」规则。
  Future<String> _importEpubAsWork(String srcPath) async {
    final id = 'novel_${DateTime.now().millisecondsSinceEpoch}';
    final root = await resolveLocalRoot(ref.read(settingsRepositoryProvider));
    final dstDir = Directory(p.join(root, id));
    await dstDir.create(recursive: true);
    final novel = await importEpub(await File(srcPath).readAsBytes());
    if (novel.text.isEmpty) throw const FormatException('epub 中没有可读文本');
    await File(p.join(dstDir.path, 'book.txt')).writeAsString(novel.text);
    var coverFile = '';
    if (novel.coverJpg != null) {
      await File(p.join(dstDir.path, 'cover.jpg'))
          .writeAsBytes(novel.coverJpg!);
      coverFile = 'cover.jpg';
    }
    await File(p.join(dstDir.path, 'chapters.json')).writeAsString(
      jsonEncode([
        for (final c in novel.chapters) {'title': c.title, 'para': c.para},
      ]),
    );
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final today = '${now.year}-${two(now.month)}-${two(now.day)}';
    await ref
        .read(appDatabaseProvider)
        .into(ref.read(appDatabaseProvider).works)
        .insert(
          WorksCompanion(
            id: Value(id),
            type: const Value('novel'),
            title: Value(
              novel.title.isEmpty
                  ? p.basenameWithoutExtension(srcPath)
                  : novel.title,
            ),
            author: Value(novel.author),
            status: const Value('completed'),
            tags: const Value('[]'),
            hasZh: const Value(true),
            zhQuality: const Value('medium'),
            // 元数据优先：epub 没有日期就留空，不用上传时间顶替
            publishedAt: Value(novel.publishedMonth),
            lastUpdated: Value(today),
            cover: Value(coverFile),
            localOnly: const Value(true),
            origin: const Value('manual'),
            syncedAt: Value(DateTime.now()),
          ),
        );
    return novel.title.isEmpty
        ? p.basenameWithoutExtension(srcPath)
        : novel.title;
  }

  /// 浏览选择文件：epub 可多选直接导入；txt 单选回填路径走表单。
  Future<void> _browse() async {
    final repo = ref.read(settingsRepositoryProvider);
    final last = (await repo.get('picker.last_dir'))?.trim() ?? '';
    if (!mounted) return;
    final picked = await showNovelPicker(
      context,
      initialDir: last.isNotEmpty ? last : r'D:\',
    );
    if (picked == null || picked.isEmpty) return;
    await repo.set('picker.last_dir', p.dirname(picked.first));
    final epubs = picked
        .where((e) => e.toLowerCase().endsWith('.epub'))
        .toList();
    final txts = picked.where((e) => e.toLowerCase().endsWith('.txt')).toList();
    if (txts.isNotEmpty) setState(() => _filePath.text = txts.first);
    if (epubs.isEmpty) return;
    var ok = 0;
    String? lastErr;
    for (final path in epubs) {
      try {
        await _importEpubAsWork(path);
        ok++;
      } on Object catch (e) {
        lastErr = '${p.basename(path)}: $e';
      }
    }
    _refreshShelf();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lastErr == null
              ? '已导入 $ok 本（书名/作者/封面自动带出）'
              : '导入 $ok 本，1 本失败：$lastErr',
        ),
      ),
    );
    if (txts.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加作品（本地）'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'manga', label: Text('漫画')),
                  ButtonSegment(value: 'novel', label: Text('小说')),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: '标题 *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '标题必填' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleJp,
                decoration: const InputDecoration(
                  labelText: '日文名',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              // 系列/卷不在此处维护——归作品页的分卷（分P）管理，随内容上传设置
              TextFormField(
                controller: _author,
                decoration: const InputDecoration(
                  labelText: '作者',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: '状态',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final s in const [
                          'completed',
                          'ongoing',
                          'hiatus',
                        ])
                          DropdownMenuItem(
                            value: s,
                            child: Text(statusLabel(s)),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _status = v ?? 'completed';
                        // 完结时上传时间即完结时间；改回连载/休载则清空
                        _completedAt = _status == 'completed' ? _thisMonth : '';
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: '标签（逗号分隔）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(true),
                      child: Text(
                        _publishedAt.isEmpty ? '发布时间…' : '发布 $_publishedAt',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(false),
                      child: Text(
                        _completedAt.isEmpty ? '完结时间…' : '完结 $_completedAt',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '时间默认取上传当月（epub 有出版日期则自动带出）；状态选"完结"时，完结时间 = 发布时间 = 上传时间',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _filePath,
                      decoration: const InputDecoration(
                        labelText:
                            '本地文件路径（可选；小说 .txt 直接复制，.epub 自动解析书名/作者/封面/章节）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '浏览选择文件',
                    icon: const Icon(Icons.folder_open),
                    onPressed: _browse,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '添加'),
        ),
      ],
    );
  }
}

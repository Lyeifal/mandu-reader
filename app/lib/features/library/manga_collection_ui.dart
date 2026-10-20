import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'manga_collections.dart';
import 'shelf_query.dart';

class MangaCollectionBar extends StatelessWidget {
  const MangaCollectionBar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.onManage,
  });
  final List<MangaCollectionSummary> items;
  final int selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView(
      key: const ValueKey('manga-collection-bar'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: [
        _chip('全部漫画', 0),
        const SizedBox(width: 6),
        _chip('未归类', -1),
        for (final item in items) ...[
          const SizedBox(width: 6),
          _chip('${item.name} (${item.count})', item.id),
        ],
        const SizedBox(width: 6),
        ActionChip(
          avatar: const Icon(Icons.folder_open, size: 16),
          label: const Text('管理'),
          onPressed: onManage,
        ),
      ],
    ),
  );

  Widget _chip(String label, int id) => ChoiceChip(
    label: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    selected: selectedId == id,
    showCheckmark: false,
    onSelected: (_) => onSelect(id),
  );
}

class MangaCollectionManager extends ConsumerStatefulWidget {
  const MangaCollectionManager({super.key});
  @override
  ConsumerState<MangaCollectionManager> createState() =>
      _MangaCollectionManagerState();
}

class _MangaCollectionManagerState
    extends ConsumerState<MangaCollectionManager> {
  bool _busy = false;
  String? _error;

  Future<void> _edit(MangaCollectionSummary? item) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CollectionNameDialog(
        title: item == null ? '新建收藏夹' : '重命名收藏夹',
        submitLabel: '保存',
        initialName: item?.name ?? '',
      ),
    );
    if (name == null || !mounted) return;
    if (name.trim().isEmpty) {
      setState(() => _error = '收藏夹名称不能为空');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = container.read(mangaCollectionsRepositoryProvider);
      if (item == null) {
        await repo.create(name);
      } else {
        await repo.rename(item.id, name);
      }
      refreshMangaCollectionShelf(container);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(MangaCollectionSummary item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: Text('确定删除“${item.name}”吗？只删除收藏夹及归属关系，漫画文件会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await container.read(mangaCollectionsRepositoryProvider).delete(item.id);
      refreshMangaCollectionShelf(container);
      final filter = container.read(shelfFilterProvider);
      if (filter.collectionId == item.id) {
        container
            .read(shelfFilterProvider.notifier)
            .apply(filter.copyWith(collectionId: 0));
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '删除失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('管理漫画收藏夹'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_busy) const LinearProgressIndicator(),
          Flexible(
            child: Consumer(
              builder: (context, ref, _) => ref
                  .watch(mangaCollectionsProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('加载失败：$e'),
                    data: (items) => items.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('还没有收藏夹'),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final item in items)
                                ListTile(
                                  title: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text('${item.count} 部漫画'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: '重命名 ${item.name}',
                                        onPressed: _busy
                                            ? null
                                            : () => _edit(item),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: '删除 ${item.name}',
                                        onPressed: _busy
                                            ? null
                                            : () => _delete(item),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _edit(null),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('新建收藏夹'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('完成'),
      ),
    ],
  );
}

Future<void> showMangaCollectionManager(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const MangaCollectionManager(),
    );

Future<int?> showMangaCollectionPicker(BuildContext context) =>
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _MangaCollectionPicker(),
    );

class _MangaCollectionPicker extends ConsumerStatefulWidget {
  const _MangaCollectionPicker();

  @override
  ConsumerState<_MangaCollectionPicker> createState() =>
      _MangaCollectionPickerState();
}

class _MangaCollectionPickerState
    extends ConsumerState<_MangaCollectionPicker> {
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          const _CollectionNameDialog(title: '新建收藏夹', submitLabel: '创建'),
    );
    if (name == null || !mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await container
          .read(mangaCollectionsRepositoryProvider)
          .create(name);
      refreshMangaCollectionShelf(container);
      if (mounted) Navigator.pop(context, id);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '创建失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Consumer(
      builder: (context, ref, _) => ref
          .watch(mangaCollectionsProvider)
          .when(
            loading: () => const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                SizedBox(height: 150, child: Center(child: Text('收藏夹加载失败：$e'))),
            data: (items) => ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('加入收藏夹')),
                if (_error != null)
                  ListTile(
                    title: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                for (final item in items)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: _busy ? null : () => Navigator.pop(context, item.id),
                  ),
                ListTile(
                  leading: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.create_new_folder_outlined),
                  title: const Text('新建收藏夹'),
                  onTap: _busy ? null : _create,
                ),
              ],
            ),
          ),
    ),
  );
}

class _CollectionNameDialog extends StatefulWidget {
  const _CollectionNameDialog({
    required this.title,
    required this.submitLabel,
    this.initialName = '',
  });
  final String title;
  final String submitLabel;
  final String initialName;

  @override
  State<_CollectionNameDialog> createState() => _CollectionNameDialogState();
}

class _CollectionNameDialogState extends State<_CollectionNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        if (_error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isEmpty) {
            setState(() => _error = '收藏夹名称不能为空');
            return;
          }
          Navigator.pop(context, value);
        },
        child: Text(widget.submitLabel),
      ),
    ],
  );
}

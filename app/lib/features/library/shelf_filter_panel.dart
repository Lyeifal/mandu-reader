import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shelf_query.dart';

/// 小说分类（参考起点/番茄）：打上对应标签即归入该分类。
const novelCategories = [
  '玄幻',
  '奇幻',
  '武侠',
  '仙侠',
  '都市',
  '历史',
  '军事',
  '游戏',
  '体育',
  '科幻',
  '悬疑',
  '诸天无限',
  '轻小说',
  '古代言情',
  '现代言情',
  '幻想言情',
  '浪漫青春',
  '短篇',
];

/// 标签逻辑色：与=绿，或=蓝，非=红。
Color tagModeColor(TagMode mode) => switch (mode) {
  TagMode.and => const Color(0xFF4CAF7D),
  TagMode.or => const Color(0xFF4C8DFF),
  TagMode.not => const Color(0xFFE05C5C),
};

/// 标签逻辑循环：或 → 非 → 与 → 或…
TagMode nextTagMode(TagMode mode) => switch (mode) {
  TagMode.or => TagMode.not,
  TagMode.not => TagMode.and,
  TagMode.and => TagMode.or,
};

/// 左侧筛选面板：时间 / （漫画）状态 / （小说）分类 / 标签（历史+新增）/ 其他。
///
/// 标签交互：点未选中的标签 = 选中（首枚标签时逻辑置"或"）；
/// 点已选中的标签 = 逻辑循环 或→非→与；右键 = 取消选中。
class ShelfFilterPanel extends ConsumerStatefulWidget {
  const ShelfFilterPanel({super.key});

  @override
  ConsumerState<ShelfFilterPanel> createState() => _ShelfFilterPanelState();
}

class _ShelfFilterPanelState extends ConsumerState<ShelfFilterPanel> {
  /// 内联月份编辑器：'' 关闭 | 'from' | 'to'
  String _editing = '';
  int _editYear = DateTime.now().year;

  void _apply(ShelfFilter next) {
    ref.read(shelfFilterProvider.notifier).apply(next);
    ref.read(shelfPageProvider.notifier).go(1);
  }

  void _openEditor(String which, ShelfFilter filter) {
    final cur = which == 'from' ? filter.timeFrom : filter.timeTo;
    setState(() {
      if (_editing == which) {
        _editing = '';
      } else {
        _editing = which;
        _editYear = cur.isNotEmpty
            ? int.tryParse(cur.substring(0, 4)) ?? DateTime.now().year
            : DateTime.now().year;
      }
    });
  }

  void _pickMonthOf(int m, ShelfFilter filter) {
    final v = '$_editYear-${m.toString().padLeft(2, '0')}';
    _apply(
      _editing == 'from'
          ? filter.copyWith(timeFrom: v)
          : filter.copyWith(timeTo: v),
    );
    setState(() => _editing = '');
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(shelfFilterProvider);
    final tags = ref.watch(shelfTagsProvider(filter.type)).value ?? const [];
    final recent = ref.watch(recentTagsProvider).value ?? const [];
    final queries = ref.watch(recentQueriesProvider).value ?? const [];
    final statuses = ref.watch(shelfStatusesProvider).value ?? const [];

    final history =
        tags
            .where((t) => tagActivityRank(t.tag, recent, queries) < (1 << 30))
            .toList()
          ..sort(
            (a, b) => tagActivityRank(
              a.tag,
              recent,
              queries,
            ).compareTo(tagActivityRank(b.tag, recent, queries)),
          );
    final fresh =
        tags
            .where((t) => tagActivityRank(t.tag, recent, queries) >= (1 << 30))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    final theme = Theme.of(context);
    final compact = theme.copyWith(
      chipTheme: theme.chipTheme.copyWith(
        labelStyle:
            theme.chipTheme.labelStyle?.copyWith(fontSize: 11.5) ??
            const TextStyle(fontSize: 11.5),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
    );
    final groupTitle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.outline,
      fontSize: 11,
      letterSpacing: 2,
    );

    return Theme(
      data: compact,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          if (filter.type == 'novel') ...[
            const SizedBox(height: 14),
            _group('分类', groupTitle, [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _miniChip(
                    context,
                    label: '全部',
                    selected: filter.novelCat.isEmpty,
                    onTap: () => _apply(filter.copyWith(novelCat: '')),
                  ),
                  for (final c in novelCategories)
                    _miniChip(
                      context,
                      label: c,
                      selected: filter.novelCat == c,
                      onTap: () => _apply(filter.copyWith(novelCat: c)),
                    ),
                ],
              ),
            ]),
          ],
          const SizedBox(height: 14),
          _group('历史标签', groupTitle, [
            if (history.isEmpty)
              Text(
                '点过的标签和搜过的关键词会出现在这里',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              )
            else
              _tagCloud(context, history, filter),
          ]),
          const SizedBox(height: 14),
          _group('新增标签', groupTitle, [
            if (fresh.isEmpty)
              Text(
                '暂无新标签',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              )
            else
              _tagCloud(context, fresh, filter),
          ]),
          _group('时间', groupTitle, [
            Row(
              children: [
                _miniChip(
                  context,
                  label: '按发布',
                  selected: filter.timeField == TimeField.published,
                  onTap: () =>
                      _apply(filter.copyWith(timeField: TimeField.published)),
                ),
                const SizedBox(width: 6),
                _miniChip(
                  context,
                  label: '按完结',
                  selected: filter.timeField == TimeField.completed,
                  onTap: () =>
                      _apply(filter.copyWith(timeField: TimeField.completed)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _timeBound(
                    context,
                    label: '从',
                    value: filter.timeFrom,
                    active: _editing == 'from',
                    onTap: () => _openEditor('from', filter),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _timeBound(
                    context,
                    label: '到',
                    value: filter.timeTo,
                    active: _editing == 'to',
                    onTap: () => _openEditor('to', filter),
                  ),
                ),
                if (filter.hasTimeRange) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () =>
                        _apply(filter.copyWith(timeFrom: '', timeTo: '')),
                    child: const Icon(Icons.close, size: 14),
                  ),
                ],
              ],
            ),
            if (_editing.isNotEmpty) ...[
              const SizedBox(height: 6),
              _monthEditor(context, filter),
            ],
          ]),
          if (filter.type == 'manga') ...[
            const SizedBox(height: 14),
            _group('状态', groupTitle, [
              Row(
                children: [
                  _miniChip(
                    context,
                    label: '不限',
                    selected: filter.status.isEmpty,
                    onTap: () => _apply(filter.copyWith(status: '')),
                  ),
                  const SizedBox(width: 6),
                  _miniChip(
                    context,
                    label: '连载中',
                    selected: filter.status == 'ongoing',
                    selectedColor: const Color(0xFF4CAF7D),
                    onTap: () => _apply(filter.copyWith(status: 'ongoing')),
                  ),
                  const SizedBox(width: 6),
                  _miniChip(
                    context,
                    label: '已完结',
                    selected: filter.status == 'completed',
                    selectedColor: const Color(0xFF4C8DFF),
                    onTap: () => _apply(filter.copyWith(status: 'completed')),
                  ),
                ],
              ),
              if (statuses.any(
                (s) => s.status != 'ongoing' && s.status != 'completed',
              ))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in statuses)
                        if (s.status != 'ongoing' && s.status != 'completed')
                          _miniChip(
                            context,
                            label: statusLabel(s.status),
                            selected: filter.status == s.status,
                            onTap: () =>
                                _apply(filter.copyWith(status: s.status)),
                          ),
                    ],
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 14),
          if (filter.author.isNotEmpty)
            _group('作者', groupTitle, [
              InputChip(
                label: Text(filter.author),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => _apply(filter.copyWith(author: '')),
              ),
            ]),
          if (filter.author.isNotEmpty) const SizedBox(height: 14),
          _group('存储', groupTitle, [
            Row(
              children: [
                _miniChip(
                  context,
                  label: '不限',
                  selected: filter.storage.isEmpty,
                  onTap: () => _apply(filter.copyWith(storage: '')),
                ),
                const SizedBox(width: 6),
                _miniChip(
                  context,
                  label: '本地',
                  selected: filter.storage == 'local',
                  onTap: () => _apply(filter.copyWith(storage: 'local')),
                ),
                const SizedBox(width: 6),
                _miniChip(
                  context,
                  label: '云端',
                  selected: filter.storage == 'cloud',
                  onTap: () => _apply(filter.copyWith(storage: 'cloud')),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          _group('排序', groupTitle, [
            Row(
              children: [
                _miniChip(
                  context,
                  label: '同步',
                  selected: filter.sort == ShelfSort.syncedAt,
                  onTap: () =>
                      _apply(filter.copyWith(sort: ShelfSort.syncedAt)),
                ),
                const SizedBox(width: 6),
                _miniChip(
                  context,
                  label: '更新',
                  selected: filter.sort == ShelfSort.lastUpdated,
                  onTap: () =>
                      _apply(filter.copyWith(sort: ShelfSort.lastUpdated)),
                ),
                const SizedBox(width: 6),
                _miniChip(
                  context,
                  label: '标题',
                  selected: filter.sort == ShelfSort.title,
                  onTap: () => _apply(filter.copyWith(sort: ShelfSort.title)),
                ),
              ],
            ),
          ]),
          if (!filter.isDefault) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('清空筛选'),
              onPressed: () => _apply(
                // 保留页签与排序，只清条件
                filter.copyWith(
                  novelCat: '',
                  author: '',
                  status: '',
                  tagModes: const {},
                  storage: '',
                  query: '',
                  timeFrom: '',
                  timeTo: '',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 从/到下拉样式按钮。
  Widget _timeBound(
    BuildContext context, {
    required String label,
    required String value,
    required bool active,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Text(
              '$label ',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '不限' : value,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  /// 内联月份编辑器：‹ 年 › + 12 个月。
  Widget _monthEditor(BuildContext context, ShelfFilter filter) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _editYear--),
                child: const Icon(Icons.chevron_left, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_editYear 年',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _editYear++),
                child: const Icon(Icons.chevron_right, size: 18),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _apply(
                    _editing == 'from'
                        ? filter.copyWith(timeFrom: '')
                        : filter.copyWith(timeTo: ''),
                  );
                  setState(() => _editing = '');
                },
                child: Text(
                  '清除',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.9,
            children: [
              for (var m = 1; m <= 12; m++)
                InkWell(
                  onTap: () => _pickMonthOf(m, filter),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _editYear == now.year && m == now.month
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text('$m', style: const TextStyle(fontSize: 11.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 小 chips：无 √，选中用颜色标识。
  Widget _miniChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: selectedColor ?? theme.colorScheme.primary,
      labelStyle: TextStyle(
        fontSize: 11.5,
        color: selected ? Colors.white : theme.colorScheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }

  /// 标签云：每个标签独立逻辑（或=蓝/非=红/与=绿）；
  /// 左键：未选中→选中（或），已选中→本标签循环 或→非→与；右键：取消选中。
  Widget _tagCloud(
    BuildContext context,
    List<({String tag, int count})> tags,
    ShelfFilter filter,
  ) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final t in tags)
        GestureDetector(
          onSecondaryTap: () {
            if (filter.tagModes.containsKey(t.tag)) {
              final modes = Map.of(filter.tagModes)..remove(t.tag);
              _apply(filter.copyWith(tagModes: modes));
            }
          },
          child: Builder(
            builder: (context) {
              final mode = filter.tagModes[t.tag];
              final isIn = mode != null;
              return FilterChip(
                label: Text(t.tag),
                showCheckmark: false,
                selected: isIn,
                selectedColor: tagModeColor(mode ?? TagMode.or)
                    .withValues(alpha: 0.9),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  color: isIn
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  final modes = Map.of(filter.tagModes);
                  if (!isIn) {
                    modes[t.tag] = TagMode.or;
                    pushRecentTag(ref, t.tag);
                  } else {
                    modes[t.tag] = nextTagMode(mode);
                  }
                  _apply(filter.copyWith(tagModes: modes));
                },
              );
            },
          ),
        ),
    ],
  );

  Widget _group(String title, TextStyle? style, List<Widget> children) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: style),
          const SizedBox(height: 6),
          ...children,
        ],
      );
}

/// 年月选择弹窗（添加作品用），返回 'YYYY-MM'；'清除' 返回 ''；取消返回 null。
Future<String?> showMonthPicker({
  required BuildContext context,
  required String? initial,
  String title = '选择月份',
}) async {
  final now = DateTime.now();
  var year = initial != null
      ? int.tryParse(initial.substring(0, 4)) ?? now.year
      : now.year;
  var month = initial != null
      ? int.tryParse(initial.substring(5, 7)) ?? now.month
      : now.month;

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => year--),
                  ),
                  Text(
                    '$year 年',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => year++),
                  ),
                ],
              ),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [
                  for (var m = 1; m <= 12; m++)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: m == month
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        foregroundColor: m == month
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        setState(() => month = m);
                        Navigator.of(context)
                            .pop('$year-${m.toString().padLeft(2, '0')}');
                      },
                      child: Text('$m 月'),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    child: const Text('清除'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String statusLabel(String status) => switch (status) {
  'ongoing' => '连载中',
  'completed' => '已完结',
  'hiatus' => '休载',
  _ => status,
};

String qualityLabel(String quality) => switch (quality) {
  'high' => '高',
  'medium' => '中',
  'low' => '低',
  _ => quality,
};

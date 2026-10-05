/// 「找书」页签：多书源聚合搜索（书架第四页签，范式同 JmBrowseView）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../source_http.dart';
import '../source_models.dart';
import '../source_providers.dart';
import '../source_search.dart';
import '../source_selector.dart';
import 'source_detail_sheet.dart';

class SourceBrowseView extends ConsumerStatefulWidget {
  const SourceBrowseView({super.key});

  @override
  ConsumerState<SourceBrowseView> createState() => _SourceBrowseViewState();
}

class _SearchEntry {
  _SearchEntry(this.result, this.error);

  final SourceSearchResult? result;
  final String? error;
}

class _SourceBrowseViewState extends ConsumerState<SourceBrowseView> {
  final _query = TextEditingController();
  String _keyword = '';
  String? _onlySource; // 限定单源（chips）
  List<_SearchEntry> _results = const [];
  bool _searching = false;
  int _doneCount = 0;

  Future<void> _search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty || _searching) return;
    setState(() {
      _keyword = trimmed;
      _results = const [];
      _searching = true;
      _doneCount = 0;
    });
    final sources = ref.read(enabledSourcesProvider);
    final targets = sources
        .where(
          (r) =>
              r.searchable &&
              (_onlySource == null || r.sourceId == _onlySource),
        )
        .toList();
    if (targets.isEmpty) {
      setState(() => _searching = false);
      return;
    }
    final limit =
        int.tryParse(
          await ref
                  .read(settingsRepositoryProvider)
                  .get('source.search_page_limit') ??
              '5',
        ) ??
        5;

    // 多源并发聚合，单源失败不拖垮整体
    await Future.wait(
      targets.map((rule) async {
        SourceHttp http;
        try {
          http = await buildSourceHttp(ref.read, rule);
        } on Object {
          return;
        }
        final engine = SelectorEngine();
        try {
          final results = await SourceSearch(
            rule,
            http,
            engine,
          ).search(trimmed, limit: limit).timeout(const Duration(seconds: 45));
          if (!mounted) return;
          setState(() {
            _results = [
              ..._results,
              for (final r in results) _SearchEntry(r, null),
            ];
          });
        } on Object catch (e) {
          if (!mounted) return;
          setState(() {
            _results = [
              ..._results,
              _SearchEntry(
                null,
                '${rule.name}: ${e.toString().split('\n').first}',
              ),
            ];
          });
        } finally {
          if (mounted) setState(() => _doneCount++);
        }
      }),
    );
    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref
        .watch(enabledSourcesProvider)
        .where((r) => r.searchable)
        .toList();
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  decoration: const InputDecoration(
                    hintText: '书名 / 作者（多书源聚合搜索）',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _search,
                ),
              ),
              const SizedBox(width: 8),
              if (_searching)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  _keyword.isEmpty
                      ? '${sources.length} 源可用'
                      : '$_doneCount/${_onlySource == null ? sources.length : 1} 源',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final r in sources)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r.name),
                    selected: _onlySource == r.sourceId,
                    showCheckmark: false,
                    onSelected: (_) => setState(
                      () => _onlySource = _onlySource == r.sourceId
                          ? null
                          : r.sourceId,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _keyword.isEmpty
              ? Center(
                  child: Text(
                    sources.isEmpty
                        ? '没有启用的书源\n到书架菜单「书源管理」开启或导入'
                        : '${sources.length} 个书源可用\n输入关键词开始搜书',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final e = _results[i];
                    if (e.error != null) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: Colors.orange,
                        ),
                        title: Text(
                          e.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      );
                    }
                    final r = e.result!;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.book_outlined),
                      title: Text(
                        r.bookName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          r.author,
                          if (r.latestChapter.isNotEmpty)
                            '更至 ${r.latestChapter}',
                          if (r.status.isNotEmpty) r.status,
                          '来自 ${r.sourceName}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      onTap: () => SourceDetailSheet.show(
                        context,
                        sourceId: r.sourceId,
                        bookUrl: r.bookUrl,
                        preview: r,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

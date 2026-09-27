import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../library/index_sync.dart';
import '../providers.dart';
import '../settings/settings_page.dart';

/// 书架占位页（M1：列表 + 搜索 + 同步）。
class ShelfPage extends ConsumerStatefulWidget {
  const ShelfPage({super.key});

  static const path = '/shelf';

  @override
  ConsumerState<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends ConsumerState<ShelfPage> {
  String _query = '';
  bool _syncing = false;

  Future<void> _sync() async {
    final client = ref.read(bucketClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('桶客户端不可用，请先在设置中配置并解锁')));
      return;
    }
    setState(() => _syncing = true);
    try {
      final report = await IndexSync(
        db: ref.read(appDatabaseProvider),
        client: client,
      ).sync();
      if (!mounted) return;
      final msg = report.upToDate
          ? '已是最新'
          : '同步 ${report.upserted} 本'
                '${report.badLines.isEmpty ? '' : '，跳过坏行 ${report.badLines.length}'}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('同步失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final works = ref.watch(_worksListProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _syncing ? null : _sync,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go(SettingsPage.path),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索标题 / 作者 / 系列',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: works.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('书架为空，点右上角同步'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => _WorkTile(work: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (work.author.isNotEmpty) work.author,
      if (work.series.isNotEmpty) work.series,
      if (work.status.isNotEmpty) work.status,
    ].join(' · ');
    return ListTile(
      leading: Icon(work.type == 'manga' ? Icons.photo_library : Icons.book),
      title: Text(work.title),
      subtitle: meta.isEmpty ? null : Text(meta),
      trailing: work.localOnly ? const Icon(Icons.smartphone, size: 16) : null,
    );
  }
}

/// 书架列表查询（M1 用 LIKE；FTS5 调优归 M7，见设计文档 §9）。
final _worksListProvider = StreamProvider.family<List<Work>, String>((
  ref,
  query,
) {
  final db = ref.watch(appDatabaseProvider);
  final q = query.trim();
  final sel = db.select(db.works)
    ..orderBy([(t) => OrderingTerm.desc(t.syncedAt)]);
  if (q.isNotEmpty) {
    final like = '%$q%';
    sel.where(
      (t) => t.title.like(like) | t.author.like(like) | t.series.like(like),
    );
  }
  return sel.watch();
});

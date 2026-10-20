import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../downloader/display_image.dart';
import '../downloader/jm_tasks.dart';
import '../providers.dart';
import 'jm_account.dart';
import '../downloader/jm_download_dialog.dart';
import 'jm_api.dart';
import 'jm_models.dart';

/// 紧凑分段按钮样式：小字、小点击目标，手机上不挤。
const _segStyle = ButtonStyle(
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  ),
);

/// 「JM漫画」页：应用内直接逛 JM——排行/分类列表、标签搜索、
/// 封面网格、车号显示；点卡片看详情（标签可再搜），一键转后台下载。
class JmBrowseView extends ConsumerStatefulWidget {
  const JmBrowseView({super.key});

  @override
  ConsumerState<JmBrowseView> createState() => _JmBrowseViewState();
}

class _JmBrowseViewState extends ConsumerState<JmBrowseView> {
  static const _categories = [
    ('0', '全部'),
    ('doujin', '同人'),
    ('single', '单本'),
    ('short', '短篇'),
    ('another', '其他'),
    ('hanman', '韩漫'),
    ('meiman', '美漫'),
    ('doujin_cosplay', 'COS'),
    ('3D', '3D'),
  ];

  static const _orders = [
    ('mr', '最新'),
    ('mv', '最多观看'),
    ('mp', '图片数'),
    ('tf', '最多喜欢'),
    ('md', '最多评论'),
  ];

  static const _times = [('a', '全部时间'), ('t', '今天'), ('w', '本周'), ('m', '本月')];

  final _search = TextEditingController();
  late JmApiClient _client = JmApiClient(proxy: _proxy);

  String _proxy = '';
  String _mode = 'rank'; // rank 排行 | fav 收藏夹
  String _folderId = '0';
  List<JmFolder> _folders = const [];
  String _loginUser = '';
  String _category = '0';
  String _order = 'mv';
  String _time = 'a';
  String _query = '';
  int _page = 1;
  int _total = 0;
  List<JmSearchItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = ref.read(settingsRepositoryProvider);
    final proxy = (await repo.get('downloader.jm_proxy'))?.trim() ?? '';
    final ffmpeg = (await repo.get('downloader.ffmpeg'))?.trim() ?? '';
    _proxy = proxy;
    _ffmpeg = ffmpeg;
    await _load(1);
  }

  String _ffmpeg = 'ffmpeg';

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _client.bootstrap();
      if (_mode == 'fav') {
        if (!await _ensureLogin()) {
          setState(() {
            _loading = false;
            _items = const [];
            _total = 0;
          });
          return;
        }
        final fp = await _client.favorites(
          page: page,
          folderId: _folderId,
          order: _order,
        );
        if (!mounted) return;
        setState(() {
          _folders = fp.folders;
          _items = fp.items;
          _total = fp.total;
          _page = page;
          _loading = false;
        });
        return;
      }
      final sp = _query.trim().isNotEmpty
          ? await _client.search(
              _query.trim(),
              page: page,
              order: _order,
              time: _time,
            )
          : await _client.category(
              page,
              category: _category,
              order: _order,
              time: _time,
            );
      if (!mounted) return;
      if (sp.redirectAlbumId != null) {
        // 直接搜到车号：弹详情
        setState(() => _loading = false);
        await _showDetail(sp.redirectAlbumId!);
        return;
      }
      setState(() {
        _items = sp.items;
        _total = sp.total;
        _page = page;
        _loading = false;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('StateError: ', '');
          _loading = false;
        });
      }
    }
  }

  /// 确保已登录：内存会话 → 存储的账号自动登录 → 弹登录框。
  Future<bool> _ensureLogin() async {
    if (_client.isLoggedIn) return true;
    final stored = await JmAccountStore.read();
    if (stored != null) {
      try {
        final info = await _client.login(stored.$1, stored.$2);
        _loginUser = info.username;
        return true;
      } on Object {
        // 存储的凭证失效，走手动登录
      }
    }
    return _showLoginDialog();
  }

  Future<bool> _showLoginDialog() async {
    final user = TextEditingController();
    final pass = TextEditingController();
    var save = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('登录 JM 账号'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: user,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('记住账号（加密存储）', style: TextStyle(fontSize: 12)),
                value: save,
                onChanged: (v) => setD(() => save = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return false;
    try {
      final info = await _client.login(user.text.trim(), pass.text);
      if (save) {
        await JmAccountStore.save(user.text.trim(), pass.text);
      }
      _loginUser = info.username;
      return true;
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '登录失败: ${e.toString().replaceFirst('StateError: ', '')}',
            ),
          ),
        );
      }
      return false;
    } finally {
      user.dispose();
      pass.dispose();
    }
  }

  Future<void> _logout() async {
    await JmAccountStore.clear();
    _client.close();
    _client = JmApiClient(proxy: _proxy);
    _loginUser = '';
    setState(() {
      _mode = 'rank';
      _items = const [];
      _total = 0;
    });
    _load(1);
  }

  @override
  void dispose() {
    _client.close();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 工具行：模式（排行/收藏夹）+ 搜索（仅排行）/ 登录态（仅收藏夹）
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'rank', label: Text('排行')),
                  ButtonSegment(value: 'fav', label: Text('收藏夹')),
                ],
                selected: {_mode},
                style: _segStyle,
                onSelectionChanged: (v) {
                  setState(() => _mode = v.first);
                  _load(1);
                },
              ),
              const SizedBox(width: 8),
              if (_mode == 'rank')
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: '搜索标题 / 作者 / 车号 / 标签',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      _query = v;
                      _load(1);
                    },
                  ),
                )
              else
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          _loginUser.isEmpty ? '未登录' : '已登录：$_loginUser',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _client.isLoggedIn
                            ? _logout
                            : () async {
                                if (await _showLoginDialog() && mounted) {
                                  _load(1);
                                }
                              },
                        child: Text(_client.isLoggedIn ? '退出登录' : '登录'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              // 下载快捷入口（车号/链接直下）：原书架顶栏按钮已随页签化移除
              IconButton(
                tooltip: 'JM 下载（车号 / 链接）',
                icon: const Icon(Icons.cloud_download),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => const JmDownloadDialog(),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '$_total 部',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
        // 排行：分类/排序/时间；收藏夹：分组/收藏排序
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (_mode == 'rank') ...[
                for (final (value, label) in _categories)
                  _chip(label, _query.isEmpty && _category == value, () {
                    setState(() {
                      _category = value;
                      _query = '';
                      _search.clear();
                    });
                    _load(1);
                  }),
                const SizedBox(width: 12),
                for (final (value, label) in _orders)
                  _chip(label, _order == value, () {
                    setState(() => _order = value);
                    _load(_page);
                  }),
                const SizedBox(width: 12),
                for (final (value, label) in _times)
                  _chip(label, _time == value, () {
                    setState(() => _time = value);
                    _load(_page);
                  }),
              ] else ...[
                for (final f in _folders)
                  _chip(f.name.isEmpty ? '默认' : f.name, _folderId == f.fid, () {
                    setState(() => _folderId = f.fid);
                    _load(1);
                  }),
                if (_folders.isNotEmpty) const SizedBox(width: 12),
                _chip('收藏时间', _order == 'mr', () {
                  setState(() => _order = 'mr');
                  _load(_page);
                }),
                _chip('更新时间', _order == 'mp', () {
                  setState(() => _order = 'mp');
                  _load(_page);
                }),
              ],
            ],
          ),
        ),
        // 网格
        Expanded(
          child: _error != null
              ? Center(child: Text('加载失败：$_error'))
              : _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? const Center(child: Text('没有结果'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    childAspectRatio: 0.56,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) => _JmCard(
                    item: _items[i],
                    proxy: _proxy,
                    onTap: () => _showDetail(_items[i].albumId),
                  ),
                ),
        ),
        // 翻页
        if (_total > 0)
          _JmPager(page: _page, total: _total, onGoto: _loading ? null : _load),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 11.5,
        color: selected ? Colors.white : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    ),
  );

  Future<void> _showDetail(String albumId) async {
    JmAlbumInfo? album;
    try {
      album = await _client.getAlbum(albumId);
    } on Object {
      album = null;
    }
    if (!mounted) return;
    // JM 车号就是本地作品 id 的唯一部分；下载中的占位行页数为 0，
    // 不能当作已经可阅读的作品。
    final db = ref.read(appDatabaseProvider);
    final localWork = await (db.select(
      db.works,
    )..where((t) => t.id.equals('jm_$albumId'))).getSingleOrNull();
    if (!mounted) return;
    final readableWork =
        localWork != null && localWork.localOnly && (localWork.pages ?? 0) > 0
        ? localWork
        : null;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _JmDetailSheet(
        albumId: albumId,
        album: album,
        proxy: _proxy,
        localWork: readableWork,
        onTagTap: (tag) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _query = tag;
            _search.text = tag;
          });
          _load(1);
        },
        onDownload: () {
          Navigator.of(sheetContext).pop();
          startJmDownload(
            container,
            albumId: albumId,
            ffmpegPath: _ffmpeg,
            proxy: _proxy,
          );
          messenger.showSnackBar(
            SnackBar(content: Text('《${album?.title ?? albumId}》已加入下载任务')),
          );
        },
        onOpenLocal: () {
          Navigator.of(sheetContext).pop();
          if (readableWork != null && mounted) {
            context.push('/reader', extra: readableWork);
          }
        },
      ),
    );
  }
}

class _JmCard extends StatelessWidget {
  const _JmCard({required this.item, required this.proxy, required this.onTap});

  final JmSearchItem item;

  /// JM CDN 走代理（桶图片不走）。
  final String proxy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Cover(
                albumId: item.albumId,
                title: item.title,
                proxy: proxy,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'No.${item.albumId}',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.albumId, required this.title, this.proxy = ''});

  final String albumId;
  final String title;
  final String proxy;

  @override
  Widget build(BuildContext context) {
    return displayUrlImage(
      jmAlbumCoverUrl(albumId),
      fit: BoxFit.cover,
      proxy: proxy.isEmpty ? null : proxy,
      cacheWidth: 340,
      fallback: Container(
        color: Colors.black26,
        alignment: Alignment.center,
        child: Text(
          title.isEmpty ? '?' : title.substring(0, 1),
          style: const TextStyle(fontSize: 36, color: Colors.white38),
        ),
      ),
    );
  }
}

/// 详情弹层：封面大图 + 元数据 + 标签（可点击再搜）+ 下载按钮。
class _JmDetailSheet extends StatelessWidget {
  const _JmDetailSheet({
    required this.albumId,
    required this.album,
    required this.proxy,
    required this.localWork,
    required this.onTagTap,
    required this.onDownload,
    required this.onOpenLocal,
  });

  final String albumId;
  final JmAlbumInfo? album;
  final String proxy;
  final Work? localWork;
  final ValueChanged<String> onTagTap;
  final VoidCallback onDownload;
  final VoidCallback onOpenLocal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = album;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 160,
                  child: _Cover(
                    albumId: albumId,
                    title: a?.title ?? '',
                    proxy: proxy,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      a?.title ?? '车号 $albumId',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '车号：$albumId',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (a != null) ...[
                      const SizedBox(height: 6),
                      Text('作者：${a.author}', style: theme.textTheme.bodySmall),
                      Text(
                        '章节 ${a.photoIds.length} · 页数 ${a.pageCount} · 发布 ${a.pubDate}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (a != null && a.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in a.tags)
                  ActionChip(
                    label: Text(t),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onTagTap(t),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: Icon(localWork == null ? Icons.download : Icons.menu_book),
            label: Text(localWork == null ? '下载到书架' : '打开本地漫画'),
            onPressed: localWork == null ? onDownload : onOpenLocal,
          ),
        ],
      ),
    );
  }
}

class _JmPager extends StatelessWidget {
  const _JmPager({required this.page, required this.total, this.onGoto});

  final int page;
  final int total;
  final ValueChanged<int>? onGoto;

  @override
  Widget build(BuildContext context) {
    const pageSize = 20;
    final pages = (total + pageSize - 1) ~/ pageSize;
    final theme = Theme.of(context);
    final window = <Object>[];
    var prev = 0;
    for (var p = 1; p <= pages; p++) {
      if (p == 1 || p == pages || (p - page).abs() <= 2) {
        if (prev != 0 && p - prev > 1) window.add('…');
        window.add(p);
        prev = p;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: onGoto != null && page > 1
                ? () => onGoto!(page - 1)
                : null,
          ),
          for (final p in window)
            p == '…'
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                : TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(34, 34),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: onGoto != null && p != page
                        ? () => onGoto!(p as int)
                        : null,
                    child: Text('$p'),
                  ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: onGoto != null && page < pages
                ? () => onGoto!(page + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

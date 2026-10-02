/// JM 移动端 API 的响应模型与解析（对应 jmcomic 的 JmApiAdaptTool）。
/// 纯解析函数，可直接单测。
class JmEpisode {
  const JmEpisode({required this.id, required this.name, required this.sort});

  final String id;
  final String name;
  final String sort;
}

class JmAlbumInfo {
  const JmAlbumInfo({
    required this.id,
    required this.title,
    required this.authors,
    required this.tags,
    required this.works,
    required this.episodes,
    required this.pageCount,
    required this.pubDate,
  });

  final String id;
  final String title;
  final List<String> authors;
  final List<String> tags;

  /// JM「作品」字段，作为系列名。
  final List<String> works;
  final List<JmEpisode> episodes;
  final int pageCount;

  /// 'YYYY-MM-DD'（来自 addtime）。
  final String pubDate;

  String get author => authors.join(' / ');
  String get series => works.join(' / ');

  /// 单章本子 series 为空时，用 album id 自身作为 photo id。
  List<String> get photoIds =>
      episodes.isNotEmpty ? episodes.map((e) => e.id).toList() : [id];

  factory JmAlbumInfo.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? v) =>
        v is List ? v.map((e) => e.toString()).toList() : const <String>[];

    final episodes = <JmEpisode>[];
    final series = json['series'];
    if (series is List) {
      for (final e in series) {
        if (e is Map) {
          episodes.add(
            JmEpisode(
              id: (e['id'] ?? '').toString(),
              name: (e['name'] ?? '').toString(),
              sort: (e['sort'] ?? '').toString(),
            ),
          );
        }
      }
    }

    final addtime = int.tryParse((json['addtime'] ?? '0').toString()) ?? 0;
    final pub = addtime > 0
        ? DateTime.fromMillisecondsSinceEpoch(addtime * 1000)
        : DateTime.now();

    return JmAlbumInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['name'] ?? '').toString(),
      authors: strList(json['author']),
      tags: strList(json['tags']),
      works: strList(json['works']),
      episodes: episodes,
      pageCount: int.tryParse((json['total_photos'] ?? '0').toString()) ?? 0,
      pubDate:
          '${pub.year}-${pub.month.toString().padLeft(2, '0')}-${pub.day.toString().padLeft(2, '0')}',
    );
  }
}

class JmPhotoInfo {
  const JmPhotoInfo({
    required this.id,
    required this.name,
    required this.images,
  });

  final String id;
  final String name;

  /// 图片文件名数组，如 00047.webp。
  final List<String> images;

  factory JmPhotoInfo.fromJson(Map<String, dynamic> json) {
    final images = <String>[];
    final v = json['images'];
    if (v is List) {
      for (final e in v) {
        images.add(e.toString());
      }
    }
    return JmPhotoInfo(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      images: images,
    );
  }
}

/// 搜索/排行结果条目。
class JmSearchItem {
  const JmSearchItem({
    required this.albumId,
    required this.title,
    required this.author,
    required this.category,
  });

  final String albumId;
  final String title;
  final String author;
  final String category;

  factory JmSearchItem.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    return JmSearchItem(
      albumId: (json['id'] ?? '').toString(),
      title: (json['name'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
      category: cat is Map ? (cat['title'] ?? '').toString() : '',
    );
  }
}

/// 搜索/排行结果页。
class JmSearchPage {
  const JmSearchPage({
    required this.items,
    required this.total,
    this.redirectAlbumId,
  });

  final List<JmSearchItem> items;

  /// 命中总数（服务端给的是字符串数字）。
  final int total;

  /// 直接搜车号时服务端重定向到该 album id。
  final String? redirectAlbumId;

  factory JmSearchPage.fromJson(Map<String, dynamic> json) {
    final redirect = json['redirect_aid'];
    final content = json['content'];
    return JmSearchPage(
      items: content is List
          ? [
              for (final e in content)
                if (e is Map<String, dynamic>) JmSearchItem.fromJson(e),
            ]
          : const [],
      total: int.tryParse((json['total'] ?? '0').toString()) ?? 0,
      redirectAlbumId: redirect?.toString(),
    );
  }
}

/// 收藏夹分组。
class JmFolder {
  const JmFolder({required this.fid, required this.name, this.count = 0});

  final String fid;
  final String name;
  final int count;

  factory JmFolder.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['2'] ?? '').toString();
    final fid = (json['FID'] ?? json['1'] ?? '').toString();
    final count = int.tryParse((json['0'] ?? '0').toString()) ?? 0;
    return JmFolder(fid: fid, name: name, count: count);
  }
}

/// 收藏夹一页：条目与搜索结果同构，附分组列表。
class JmFavoritePage {
  const JmFavoritePage({
    required this.items,
    required this.total,
    required this.folders,
  });

  final List<JmSearchItem> items;
  final int total;
  final List<JmFolder> folders;

  factory JmFavoritePage.fromJson(Map<String, dynamic> json) {
    final list = json['list'];
    final folderList = json['folder_list'];
    return JmFavoritePage(
      items: list is List
          ? [
              for (final e in list)
                if (e is Map<String, dynamic>) JmSearchItem.fromJson(e),
            ]
          : const [],
      total: int.tryParse((json['total'] ?? '0').toString()) ?? 0,
      folders: folderList is List
          ? [
              for (final e in folderList)
                if (e is Map<String, dynamic>) JmFolder.fromJson(e),
            ]
          : const [],
    );
  }
}

/// 登录结果摘要。
class JmLoginInfo {
  const JmLoginInfo({
    required this.uid,
    required this.username,
    required this.albumFavorites,
    required this.levelName,
  });

  final String uid;
  final String username;
  final int albumFavorites;
  final String levelName;

  factory JmLoginInfo.fromJson(Map<String, dynamic> json) => JmLoginInfo(
    uid: (json['uid'] ?? '').toString(),
    username: (json['username'] ?? '').toString(),
    albumFavorites:
        int.tryParse((json['album_favorites'] ?? '0').toString()) ?? 0,
    levelName: (json['level_name'] ?? '').toString(),
  );
}

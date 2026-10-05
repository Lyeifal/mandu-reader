/// works_fts（FTS5 trigram）检索与维护工具（设计文档 §9，M7 接通）。
///
/// 写侧：[upsertWorkFts] 是**唯一**合法的 fts 行入口——所有作品登记/
/// 修改路径（云端同步/本地导入/下载登记/加标签/上传成功）都必须经它，
/// 漏一处 = 该作品关键词搜索失明（AGENTS.md 有备案）。
/// 读侧：[ftsQuery] 把用户输入转成 MATCH 短语（防语法错），查不到时
/// 调用方回退 LIKE。
library;

import '../../data/db/app_database.dart';

/// 关键词 → FTS5 MATCH 查询串：trigram 分词下「双引号短语」即子串匹配；
/// 空白拆词、各词 AND。剔除 FTS5 语法字符（" * ( ) - : ^）防注入/语法错。
/// 注意：trigram 的查询词下限是 **3 个字符**（实测 2 个汉字也匹配不到，
/// 与字节数无关）；不足 3 字符的词被丢弃，全部不足则返回 null，
/// 调用方回退 LIKE（中文 1-2 字 LIKE 毫秒级，无需强走 FTS）。
String? ftsQuery(String raw) {
  // 运算符剔除为空串（相邻汉字合并成词）；CJK 语境下比拆成碎片更合理
  final cleaned = raw.replaceAll(RegExp('["*()\\-:^]'), '');
  final terms = <String>[
    for (final t in cleaned.split(RegExp(r'\s+')))
      if (t.runes.length >= 3) t,
  ];
  if (terms.isEmpty) return null;
  return terms.map((t) => '"$t"').join(' ');
}

/// 维护一行 works_fts（DELETE + INSERT；与 index_sync 原语义一致）。
Future<void> upsertWorkFts(
  AppDatabase db, {
  required String id,
  required String title,
  String titleJp = '',
  String author = '',
  String series = '',
  List<String> tags = const [],
}) async {
  await db.customStatement('DELETE FROM works_fts WHERE id = ?', [id]);
  await db.customStatement(
    'INSERT INTO works_fts (id, title, title_jp, author, series, tags) '
    'VALUES (?,?,?,?,?,?)',
    [id, title, titleJp, author, series, tags.join(' ')],
  );
}

/// 搜索框语法糖（设计文档 §9 组合语法）：解析 `type:` / `tag:` /
/// `status:` / `作者:` 前缀 token 为过滤条件，剩余文本作关键词。
/// 前缀值大小写不敏感；type/status 值非法时忽略该 token（留作关键词也无妨，直接忽略）。
({String? type, String? tag, String? status, String? author, String keyword})
parseFilterTokens(String raw) {
  String? type;
  String? tag;
  String? status;
  String? author;
  final rest = <String>[];
  for (final tok in raw.trim().split(RegExp(r'\s+'))) {
    if (tok.isEmpty) continue;
    final idx = tok.indexOf(':');
    if (idx <= 0) {
      rest.add(tok);
      continue;
    }
    final key = tok.substring(0, idx).toLowerCase();
    final value = tok.substring(idx + 1).trim();
    if (value.isEmpty) {
      rest.add(tok);
      continue;
    }
    switch (key) {
      case 'type':
        final v = value.toLowerCase();
        if (v == 'manga' || v == 'novel') type = v;
      case 'tag' || '标签':
        tag = value;
      case 'status' || '状态':
        final v = value.toLowerCase();
        if (v == 'ongoing' || v == 'completed' || v == 'hiatus') status = v;
      case 'author' || '作者':
        author = value;
      default:
        rest.add(tok);
    }
  }
  return (
    type: type,
    tag: tag,
    status: status,
    author: author,
    keyword: rest.join(' '),
  );
}

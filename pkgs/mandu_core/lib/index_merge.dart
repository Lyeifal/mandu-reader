import 'dart:convert';

/// works.jsonl 读-改-写的内容合并：滤掉同 id 旧行后追加新行（纯函数）。

String mergeIndexLine(String existing, Map<String, Object?> entry) {
  final id = entry['id'];
  final lines = existing
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .where((line) {
        try {
          return (jsonDecode(line) as Map)['id'] != id;
        } on Object {
          return true;
        }
      })
      .toList()
    ..add(jsonEncode(entry));
  return '${lines.join('\n')}\n';
}

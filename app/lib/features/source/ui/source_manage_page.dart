/// 书源管理页：启停 / 导入 JSON / 单源测试 / 禁用原因展示。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/app_database.dart';
import '../../settings/reader_prefs.dart';
import '../../providers.dart';
import '../source_loader.dart';
import '../source_models.dart';
import '../source_ops.dart';
import '../source_providers.dart';

class SourceManagePage extends ConsumerStatefulWidget {
  const SourceManagePage({super.key});

  static const path = '/sources';

  @override
  ConsumerState<SourceManagePage> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends ConsumerState<SourceManagePage> {
  final _testing = <String, bool>{};

  Future<void> _toggle(SourceRule rule, bool enabled) async {
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.novelSources)
        .insertOnConflictUpdate(
          NovelSourcesCompanion(
            sourceId: Value(rule.sourceId),
            name: Value(rule.name),
            enabled: Value(enabled),
            disableReason: Value(enabled ? '' : '手动禁用'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> _test(SourceRule rule) async {
    setState(() => _testing[rule.sourceId] = true);
    final result = await testSource(ref.read, rule);
    if (!mounted) return;
    setState(() => _testing[rule.sourceId] = false);
    final db = ref.read(appDatabaseProvider);
    // CF 实锤 → 自动禁用；其余结果**不改变启停**——测试一个已禁用源
    // 不该把它复活（此前 fail && !disabled 的写法会把禁用的死源重新启用）
    final shouldDisable = result.startsWith('cf_challenge');
    final row = await (db.select(
      db.novelSources,
    )..where((t) => t.sourceId.equals(rule.sourceId))).getSingleOrNull();
    await db
        .into(db.novelSources)
        .insertOnConflictUpdate(
          NovelSourcesCompanion(
            sourceId: Value(rule.sourceId),
            name: Value(rule.name),
            enabled: Value(
              shouldDisable ? false : (row?.enabled ?? !rule.disabled),
            ),
            disableReason: Value(
              shouldDisable
                  ? result
                  : (row?.disableReason ?? rule.disableReason),
            ),
            lastTestResult: Value(result),
            lastTestedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${rule.name}: $result')));
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    String? content;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final path = await FilePickerDialog.show(
        context,
        title: '导入书源 JSON（数组或单条对象）',
        extensions: const {'.json'},
      );
      if (path == null) return;
      content = await File(path).readAsString();
    } else {
      content = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('粘贴书源 JSON'),
            content: TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('校验并导入'),
              ),
            ],
          );
        },
      );
    }
    if (content == null || content.trim().isEmpty || !mounted) return;
    final text = content;

    final decoded = () {
      try {
        return jsonDecode(text.trim());
      } on Object catch (e) {
        return e.toString();
      }
    }();
    if (decoded is! List) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('JSON 解析失败：${decoded is String ? decoded : '须为数组'}'),
        ),
      );
      return;
    }
    final ops = buildDefaultOps();
    final db = ref.read(appDatabaseProvider);
    var okCount = 0;
    final errors = <String>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final j = e.cast<String, dynamic>();
      if (j['sourceId']?.toString().isNotEmpty != true) {
        // 用户源无 sourceId：按 url 生成 custom slug
        final url = (j['url'] ?? '').toString();
        // String.hashCode 每次启动随机，不能作持久 id；用 url 的 md5 前 10 位
        j['sourceId'] =
            'custom_${md5.convert(utf8.encode(url)).toString().substring(0, 10)}';
      }
      final rule = SourceRule.fromJson(j['sourceId']!.toString(), j);
      final errs = validateRule(rule, ops);
      if (errs.isNotEmpty) {
        errors.add('${rule.name}: ${errs.first}');
        continue;
      }
      await db
          .into(db.novelSources)
          .insertOnConflictUpdate(
            NovelSourcesCompanion(
              sourceId: Value(rule.sourceId),
              name: Value(rule.name),
              json: Value(jsonEncode(j)),
              enabled: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
      okCount++;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          errors.isEmpty
              ? '已导入 $okCount 个书源'
              : '导入 $okCount 个，失败 ${errors.length}：${errors.first}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allSourcesProvider).value ?? const [];
    final testResults =
        ref.watch(sourceTestResultsProvider).value ??
        const <String, ({String result, DateTime? testedAt})>{};
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: '导入书源 JSON',
            icon: const Icon(Icons.add),
            onPressed: _import,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: all.length,
        itemBuilder: (context, i) {
          final r = all[i];
          final testing = _testing[r.sourceId] == true;
          return ListTile(
            dense: true,
            leading: Icon(
              r.disabled ? Icons.cloud_off : Icons.cloud_queue,
              color: r.disabled
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
            title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                r.sourceId,
                if (r.language == 'zh_TW') '繁体',
                if (r.needProxy) '需代理',
                if (testResults[r.sourceId] != null)
                  '测试：${testResults[r.sourceId]!.result}',
                if (r.disabled && r.disableReason.isNotEmpty)
                  '已禁用：${r.disableReason}',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (testing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: '单源测试（搜索→详情→目录→正文）',
                    icon: const Icon(Icons.bug_report_outlined, size: 20),
                    onPressed: () => _test(r),
                  ),
                Switch(value: !r.disabled, onChanged: (v) => _toggle(r, v)),
              ],
            ),
          );
        },
      ),
    );
  }
}

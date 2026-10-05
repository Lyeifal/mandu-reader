/// 书源巡检 harness（真实联网；不进 flutter test）。
///
/// 用法（cwd = app/）：
///   dart run tool/source_doctor.dart                  # 全部启用源四步巡检
///   dart run tool/source_doctor.dart --source xbiqugu # 单个源
///   dart run tool/source_doctor.dart --probe 名,url   # 自定义探针书
/// 代理：SOURCE_PROXY=host:port 环境变量（needProxy 源生效）。
library;

import 'dart:io';

import 'package:mandu_reader/features/source/source_http.dart';
import 'package:mandu_reader/features/source/source_loader.dart';
import 'package:mandu_reader/features/source/source_probe.dart';

Future<void> main(List<String> args) async {
  String? only;
  String? probeKeyword;
  String? probeBookUrl;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--source' && i + 1 < args.length) only = args[++i];
    if (args[i] == '--probe' && i + 1 < args.length) {
      final parts = args[++i].split(',');
      if (parts.length == 2) {
        probeKeyword = parts[0];
        probeBookUrl = parts[1];
      }
    }
  }

  final content = File('assets/rules/sources.json').readAsStringSync();
  final rules = parseRulesJson(content);
  final proxy = Platform.environment['SOURCE_PROXY']?.trim() ?? '';

  final targets = rules
      .where(
        (r) =>
            !r.disabled &&
            (only == null || r.sourceId == only || r.name.contains(only)),
      )
      .toList();
  if (targets.isEmpty) {
    stdout.writeln('没有匹配的启用源（--source 可指定；禁用的源先在管理页开启）');
    return;
  }

  var okCount = 0;
  final results = <String>[];
  for (final rule in targets) {
    stdout.write('== ${rule.sourceId} ${rule.name} ... ');
    final http = SourceHttpClient(
      proxy: rule.needProxy ? proxy : '',
      minIntervalMs: 800,
      maxIntervalMs: 1500,
    );
    final result = await probeSource(
      rule,
      http,
      probeKeyword: probeKeyword,
      probeBookUrl: probeBookUrl,
    );
    results.add('${rule.sourceId}\t${rule.name}\t$result');
    if (result == 'ok') okCount++;
    stdout.writeln(result);
  }
  stdout.writeln('');
  stdout.writeln('汇总: $okCount/${targets.length} 通过');
  for (final r in results) {
    stdout.writeln(r);
  }
}

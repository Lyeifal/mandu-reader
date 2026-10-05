import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../data/db/app_database.dart';
import '../bucket/path_helper.dart';
import '../downloader/display_image.dart';
import '../downloader/jm_pipeline.dart';
import '../library/events_log.dart';
import '../providers.dart';
import 'font_sync.dart';

part 'reader_core.dart';
part 'reader_manga_page.dart';
part 'reader_novel_page.dart';

/// 阅读器：漫画沉浸式（中央点按呼出设置，两侧点按翻页）+ 小说文本滚动。
class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.work});

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return work.type == 'manga'
        ? Scaffold(
            backgroundColor: Colors.black,
            body: _MangaReader(work: work),
          )
        : _NovelReader(work: work);
  }
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandu_reader/data/db/app_database.dart';
import 'package:mandu_reader/features/settings/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });

  tearDown(() async => db.close());

  test('缺省值回退', () async {
    expect(await repo.get('reader.novel.fontSizePx'), '16');
    expect(await repo.get('不存在'), isNull);
  });

  test('set 覆盖并标记 scope', () async {
    await repo.set('reader.novel.fontSizePx', '20', synced: true);
    expect(await repo.get('reader.novel.fontSizePx'), '20');

    final row = await (db.select(
      db.settings,
    )..where((t) => t.key.equals('reader.novel.fontSizePx'))).getSingle();
    expect(row.scope, 'synced');
  });

  test('watchAll 先给缺省、再给覆盖值', () async {
    final expectation = expectLater(
      repo.watchAll(),
      emitsThrough(
        predicate<Map<String, String>>(
          (m) => m['reader.novel.fontSizePx'] == '22',
        ),
      ),
    );
    await repo.set('reader.novel.fontSizePx', '22');
    await expectation;
  });
}

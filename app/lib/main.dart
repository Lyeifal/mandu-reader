import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'features/auth/credential_store.dart';
import 'features/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name} ${record.loggerName}: ${record.message}');
  });

  final store = SecureCredentialStore();
  final db = AppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        credentialStoreProvider.overrideWithValue(store),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const ManduApp(),
    ),
  );
}

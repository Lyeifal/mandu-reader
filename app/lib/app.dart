import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/db/app_database.dart';
import 'features/auth/auth_gate_page.dart';
import 'features/library/shelf_page.dart';
import 'features/providers.dart';
import 'features/reader/reader_page.dart';
import 'features/settings/settings_page.dart';
import 'features/source/ui/source_manage_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref
    ..onDispose(refresh.dispose)
    ..listen(authControllerProvider, (previous, next) => refresh.value++)
    ..listen(
      bucketConfigControllerProvider,
      (previous, next) => refresh.value++,
    );

  return GoRouter(
    initialLocation: ShelfPage.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider).value;
      final loc = state.matchedLocation;
      if (auth == null || !auth.isUnlocked) {
        return loc == AuthGatePage.path ? null : AuthGatePage.path;
      }
      // 解锁后直接去书架（漫画/小说页签）；桶未配置时同步/测试会提示，
      // 不再强制跳设置页打断浏览
      if (loc == AuthGatePage.path) return ShelfPage.path;
      return null;
    },
    routes: [
      GoRoute(
        path: AuthGatePage.path,
        builder: (context, state) => const AuthGatePage(),
      ),
      GoRoute(
        path: SettingsPage.path,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: ShelfPage.path,
        builder: (context, state) => const ShelfPage(),
      ),
      GoRoute(
        path: SourceManagePage.path,
        builder: (context, state) => const SourceManagePage(),
      ),
      GoRoute(
        path: '/reader',
        builder: (context, state) => ReaderPage(work: state.extra! as Work),
      ),
    ],
  );
});

class ManduApp extends ConsumerWidget {
  const ManduApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '漫读',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF16161C),
        cardColor: const Color(0xFF23232B),
        dividerColor: const Color(0xFF26262E),
      ),
      routerConfig: router,
    );
  }
}

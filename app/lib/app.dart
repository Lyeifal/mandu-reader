import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_gate_page.dart';
import 'features/library/shelf_page.dart';
import 'features/providers.dart';
import 'features/settings/settings_page.dart';

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
      final cfg = ref.read(bucketConfigControllerProvider).value;
      if ((cfg == null || cfg.secretKey.isEmpty) && loc != SettingsPage.path) {
        return SettingsPage.path;
      }
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      routerConfig: router,
    );
  }
}

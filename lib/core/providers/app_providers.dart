import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_config.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../database/local_database.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw StateError('The local database must be provided during app startup.');
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

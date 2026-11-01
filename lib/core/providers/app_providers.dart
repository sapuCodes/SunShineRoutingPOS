import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_config.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/workspaces/presentation/workspace_screens.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final gateway = ref.watch(authGatewayProvider);
  final routerRefresh = ref.watch(authRouterRefreshProvider);
  final router = GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      const publicRoutes = {
        '/sign-in',
        '/register',
        '/verify-email',
        '/forgot-password',
      };
      final identity = gateway?.currentIdentity;
      if (identity == null) {
        return publicRoutes.contains(location) ? null : '/sign-in';
      }
      if (!identity.emailVerified) {
        if (location == '/verify-email') {
          return null;
        }
        return '/verify-email?email=${Uri.encodeQueryComponent(identity.email)}';
      }
      if (location == '/forgot-password') {
        return null;
      }
      return publicRoutes.contains(location) ? '/workspace-loading' : null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/workspace-loading',
        name: 'workspace-loading',
        builder: (context, state) => const WorkspaceLoadingScreen(),
      ),
      GoRoute(
        path: '/workspaces',
        name: 'workspaces',
        builder: (context, state) => const WorkspaceSelectionScreen(),
      ),
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

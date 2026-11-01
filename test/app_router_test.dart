import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunshinerpos/core/providers/app_providers.dart';
import 'package:sunshinerpos/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  test('authentication and workspace routes are registered by name', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);

    expect(router.namedLocation('dashboard'), '/dashboard');
    expect(router.namedLocation('sign-in'), '/sign-in');
    expect(router.namedLocation('register'), '/register');
    expect(router.namedLocation('verify-email'), '/verify-email');
    expect(router.namedLocation('forgot-password'), '/forgot-password');
    expect(router.namedLocation('workspace-loading'), '/workspace-loading');
    expect(router.namedLocation('workspaces'), '/workspaces');
  });

  testWidgets('unauthenticated users cannot open a protected route', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/dashboard');
    await tester.pumpAndSettle();

    expect(find.text('Create an account'), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });
}

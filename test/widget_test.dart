import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunshinerpos/app/app_theme.dart';
import 'package:sunshinerpos/app/sunshine_pos_app.dart';
import 'package:sunshinerpos/features/workspaces/application/workspace_providers.dart';
import 'package:sunshinerpos/features/workspaces/domain/workspace_membership.dart';
import 'package:sunshinerpos/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('dashboard renders the data-free application placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceSnapshotProvider.overrideWith(
            (ref) async => const WorkspaceSnapshot(
              memberships: [],
              selectedWorkspace: null,
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sun Shine POS'), findsOneWidget);
    expect(find.text('Ready to get started?'), findsOneWidget);
    expect(find.text('Your application foundation is ready.'), findsOneWidget);
    expect(find.text('No business records have been added.'), findsOneWidget);
  });

  testWidgets('database startup failure is shown with a retry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      DatabaseStartupErrorApp(
        error: Exception('Database unavailable'),
        onRetry: () async {},
      ),
    );

    expect(find.text('Could not open local storage.'), findsOneWidget);
    expect(find.textContaining('Database unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

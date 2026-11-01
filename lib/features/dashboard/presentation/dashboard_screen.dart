import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../auth/application/auth_providers.dart';
import '../../workspaces/application/workspace_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final workspace = ref.watch(workspaceSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sun Shine POS'),
        actions: [
          IconButton(
            tooltip: 'Switch workspace',
            onPressed: () => context.go('/workspaces'),
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.point_of_sale,
                        color: AppColors.orange,
                        size: 48,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ready to get started?',
                        style: textTheme.headlineSmall?.copyWith(
                          color: AppColors.steel900,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your application foundation is ready.',
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      workspace.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (error, stackTrace) => Text(
                          'Workspace authorization could not be verified: '
                          '$error',
                          textAlign: TextAlign.center,
                        ),
                        data: (snapshot) {
                          final selected = snapshot.selectedWorkspace;
                          if (selected == null) {
                            return TextButton(
                              onPressed: () => context.go('/workspaces'),
                              child: const Text('Select a workspace'),
                            );
                          }
                          return Column(
                            children: [
                              Text(
                                selected.name,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                '${selected.type.name} workspace · '
                                '${selected.role.label}',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No business records have been added.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.steel500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) {
        context.go('/sign-in');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete sign out: $error')),
        );
      }
    }
  }
}

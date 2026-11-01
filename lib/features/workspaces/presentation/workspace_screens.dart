import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../auth/application/auth_providers.dart';
import '../application/workspace_providers.dart';
import '../domain/workspace_membership.dart';

class WorkspaceLoadingScreen extends ConsumerWidget {
  const WorkspaceLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(workspaceSnapshotProvider);
    return snapshot.when(
      loading: () => const _WorkspaceMessage(
        title: 'Loading your workspace',
        message: 'Checking your current server-verified membership.',
        loading: true,
      ),
      error: (error, stackTrace) => _WorkspaceUnavailable(
        error: error,
        onRetry: () => ref.invalidate(workspaceSnapshotProvider),
      ),
      data: (value) {
        final selected = value.selectedWorkspace;
        if (selected == null) {
          if (value.memberships.isEmpty) {
            return _WorkspaceMessage(
              title: 'Workspace not initialized',
              message:
                  'The verified account has no workspace membership. '
                  'Retry after applying the local Supabase migration.',
              onRetry: () => ref.invalidate(workspaceSnapshotProvider),
            );
          }
          return WorkspaceSelectionScreen(snapshot: value);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/dashboard');
          }
        });
        return _WorkspaceMessage(
          title: 'Opening ${selected.name}',
          message: 'Workspace access was verified by the server.',
          loading: true,
        );
      },
    );
  }
}

class WorkspaceSelectionScreen extends ConsumerWidget {
  const WorkspaceSelectionScreen({this.snapshot, super.key});

  final WorkspaceSnapshot? snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = snapshot == null
        ? ref.watch(workspaceSnapshotProvider)
        : AsyncData(snapshot!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select workspace'),
        leading: IconButton(
          tooltip: 'Sign out',
          onPressed: () => _signOut(context, ref),
          icon: const Icon(Icons.logout),
        ),
      ),
      body: current.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _WorkspaceUnavailable(
          error: error,
          onRetry: () => ref.invalidate(workspaceSnapshotProvider),
        ),
        data: (value) {
          if (value.memberships.isEmpty) {
            return const _WorkspaceMessage(
              title: 'No workspace memberships',
              message:
                  'No server-verified workspace membership is available for '
                  'this account.',
            );
          }
          return _WorkspaceList(
            snapshot: value,
            onSelect: (membership) => _selectWorkspace(
              context,
              ref,
              membership,
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectWorkspace(
    BuildContext context,
    WidgetRef ref,
    WorkspaceMembership membership,
  ) async {
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .selectWorkspace(membership);
      ref.invalidate(workspaceSnapshotProvider);
      if (context.mounted) {
        context.go('/dashboard');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select workspace: $error')),
        );
      }
    }
  }
}

class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList({required this.snapshot, required this.onSelect});

  final WorkspaceSnapshot snapshot;
  final ValueChanged<WorkspaceMembership> onSelect;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            snapshot.selectedWorkspace == null
                ? 'Choose a workspace to continue.'
                : 'Switch to another workspace.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          for (final membership in snapshot.memberships)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.orange,
                ),
                title: Text(membership.name),
                subtitle: Text(
                  '${membership.type.name} · ${membership.role.label}',
                ),
                trailing: membership.workspaceId ==
                        snapshot.selectedWorkspace?.workspaceId
                    ? const Icon(Icons.check_circle, color: AppColors.orange)
                    : const Icon(Icons.chevron_right),
                onTap: () => onSelect(membership),
              ),
            ),
        ],
      ),
    ),
  );
}

class _WorkspaceUnavailable extends ConsumerWidget {
  const _WorkspaceUnavailable({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = ref.watch(cachedWorkspacesProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.cloud_off, color: AppColors.orange, size: 40),
            const SizedBox(height: 12),
            Text(
              'Could not verify workspace access.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Cached details are display-only. The cached role is not '
              'authorization, and no workspace operation is enabled until '
              'the server verifies membership.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            cached.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (cacheError, stackTrace) => Text(
                'Cached workspace details are unavailable: $cacheError',
              ),
              data: (workspaces) => Column(
                children: [
                  for (final workspace in workspaces)
                    ListTile(
                      title: Text(workspace.name),
                      subtitle: Text(
                        '${workspace.type.name} · cached role: '
                        '${workspace.role.label} (unverified)',
                      ),
                      enabled: false,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            TextButton(
              onPressed: () => _signOut(context, ref),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String title;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sun Shine POS')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../../../core/providers/local_database_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../data/workspace_data_source.dart';
import '../domain/workspace_membership.dart';

final workspaceDataSourceProvider = Provider<WorkspaceDataSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseWorkspaceDataSource(client);
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return WorkspaceRepository(
    dataSource: ref.watch(workspaceDataSourceProvider),
    localDatabase: ref.watch(localDatabaseProvider),
  );
});

final workspaceSnapshotProvider = FutureProvider<WorkspaceSnapshot>((ref) {
  return ref.watch(workspaceRepositoryProvider).loadSnapshot();
});

final cachedWorkspacesProvider = FutureProvider<List<WorkspaceMembership>>((
  ref,
) async {
  final rows = await ref.watch(localDatabaseProvider).readCachedWorkspaces();
  return rows.map(WorkspaceMembership.fromCache).toList(growable: false);
});

final class WorkspaceRepository {
  const WorkspaceRepository({
    required this.dataSource,
    required this.localDatabase,
  });

  final WorkspaceDataSource? dataSource;
  final LocalDatabase localDatabase;

  Future<WorkspaceSnapshot> loadSnapshot() async {
    final workspaceDataSource = dataSource;
    if (workspaceDataSource == null) {
      throw StateError('Local Supabase configuration is required.');
    }

    final memberships = await workspaceDataSource.fetchMemberships();
    await localDatabase.replaceCachedWorkspaces(
      memberships.map((membership) => membership.toCacheRecord()).toList(),
    );

    final storedId = await localDatabase.readSelectedWorkspaceId();
    WorkspaceMembership? selected;
    if (storedId != null) {
      for (final membership in memberships) {
        if (membership.workspaceId == storedId) {
          selected = membership;
          break;
        }
      }
      if (selected == null) {
        await localDatabase.writeSelectedWorkspaceId(null);
      }
    }
    if (selected == null && memberships.length == 1) {
      selected = memberships.single;
      await localDatabase.writeSelectedWorkspaceId(selected.workspaceId);
    }

    return WorkspaceSnapshot(
      memberships: memberships,
      selectedWorkspace: selected,
    );
  }

  Future<void> selectWorkspace(WorkspaceMembership membership) async {
    if (!membership.authorizationVerified) {
      throw StateError(
        'A cached workspace cannot be used to authorize a selection.',
      );
    }
    await localDatabase.writeSelectedWorkspaceId(membership.workspaceId);
  }
}

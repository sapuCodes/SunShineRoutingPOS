import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_membership.dart';

abstract interface class WorkspaceDataSource {
  Future<List<WorkspaceMembership>> fetchMemberships();
}

final class SupabaseWorkspaceDataSource implements WorkspaceDataSource {
  SupabaseWorkspaceDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<WorkspaceMembership>> fetchMemberships() async {
    final user = _client.auth.currentUser;
    if (user == null || user.emailConfirmedAt == null) {
      throw StateError('A verified signed-in user is required for workspaces.');
    }

    final rows = await _client
        .from('workspace_members')
        .select(
          'workspace_id, role, workspace:workspaces!inner(id, name, type, owner_id)',
        )
        .eq('user_id', user.id);
    final verifiedAt = DateTime.now().toUtc();

    return rows.map((row) {
      final workspace = row['workspace'];
      if (workspace is! Map<String, dynamic>) {
        throw const FormatException(
          'The server returned an invalid workspace membership.',
        );
      }
      return WorkspaceMembership.fromServer(
        workspaceId: workspace['id'] as String,
        name: workspace['name'] as String,
        type: workspace['type'] as String,
        ownerId: workspace['owner_id'] as String,
        role: row['role'] as String,
        verifiedAt: verifiedAt,
      );
    }).toList(growable: false);
  }
}

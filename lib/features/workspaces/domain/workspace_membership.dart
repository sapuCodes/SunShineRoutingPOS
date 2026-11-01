import 'workspace_role.dart';

enum WorkspaceType {
  personal,
  business;

  static WorkspaceType parse(String value) {
    for (final type in values) {
      if (type.name == value) {
        return type;
      }
    }
    throw FormatException('Unknown workspace type: $value');
  }
}

final class WorkspaceMembership {
  const WorkspaceMembership({
    required this.workspaceId,
    required this.name,
    required this.type,
    required this.ownerId,
    required this.role,
    required this.lastVerifiedAt,
    required this.authorizationVerified,
  });

  factory WorkspaceMembership.fromServer({
    required String workspaceId,
    required String name,
    required String type,
    required String ownerId,
    required String role,
    required DateTime verifiedAt,
  }) {
    return WorkspaceMembership(
      workspaceId: workspaceId,
      name: name,
      type: WorkspaceType.parse(type),
      ownerId: ownerId,
      role: WorkspaceRole.parse(role),
      lastVerifiedAt: verifiedAt,
      authorizationVerified: true,
    );
  }

  factory WorkspaceMembership.fromCache(Map<String, Object?> row) {
    return WorkspaceMembership(
      workspaceId: row['workspace_id']! as String,
      name: row['name']! as String,
      type: WorkspaceType.parse(row['type']! as String),
      ownerId: row['owner_id']! as String,
      role: WorkspaceRole.parse(row['role']! as String),
      lastVerifiedAt: DateTime.parse(row['last_verified_at']! as String),
      authorizationVerified: false,
    );
  }

  final String workspaceId;
  final String name;
  final WorkspaceType type;
  final String ownerId;
  final WorkspaceRole role;
  final DateTime lastVerifiedAt;
  final bool authorizationVerified;

  Map<String, Object?> toCacheRecord() => {
    'workspace_id': workspaceId,
    'name': name,
    'type': type.name,
    'owner_id': ownerId,
    'role': role.label,
    'last_verified_at': lastVerifiedAt.toUtc().toIso8601String(),
  };
}

final class WorkspaceSnapshot {
  const WorkspaceSnapshot({
    required this.memberships,
    required this.selectedWorkspace,
  });

  final List<WorkspaceMembership> memberships;
  final WorkspaceMembership? selectedWorkspace;
}

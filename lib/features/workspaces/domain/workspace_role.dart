enum WorkspaceRole {
  owner('Owner'),
  admin('Admin'),
  manager('Manager'),
  salesperson('Salesperson'),
  cashier('Cashier');

  const WorkspaceRole(this.label);

  final String label;

  static WorkspaceRole parse(String value) {
    for (final role in values) {
      if (role.label == value) {
        return role;
      }
    }
    throw FormatException('Unknown workspace role: $value');
  }
}

enum WorkspacePermission {
  manageWorkspaceSettings,
  manageMembers,
  inviteMembers,
  transferOwnership,
  deleteWorkspace,
  manageOperations,
  createSales,
  limitedProductAccess,
}

extension WorkspaceRolePermissions on WorkspaceRole {
  bool grants(WorkspacePermission permission) {
    if (this == WorkspaceRole.owner) {
      return true;
    }

    return switch (this) {
      WorkspaceRole.admin => const {
        WorkspacePermission.manageWorkspaceSettings,
        WorkspacePermission.manageMembers,
        WorkspacePermission.inviteMembers,
        WorkspacePermission.manageOperations,
        WorkspacePermission.createSales,
        WorkspacePermission.limitedProductAccess,
      }.contains(permission),
      WorkspaceRole.manager => const {
        WorkspacePermission.manageOperations,
        WorkspacePermission.createSales,
        WorkspacePermission.limitedProductAccess,
      }.contains(permission),
      WorkspaceRole.salesperson || WorkspaceRole.cashier => const {
        WorkspacePermission.createSales,
        WorkspacePermission.limitedProductAccess,
      }.contains(permission),
      WorkspaceRole.owner => true,
    };
  }
}

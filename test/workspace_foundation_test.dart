import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sunshinerpos/core/database/local_database.dart';
import 'package:sunshinerpos/features/workspaces/application/workspace_providers.dart';
import 'package:sunshinerpos/features/workspaces/data/workspace_data_source.dart';
import 'package:sunshinerpos/features/workspaces/domain/workspace_membership.dart';
import 'package:sunshinerpos/features/workspaces/domain/workspace_role.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('workspace selection persists and cached role is not verified', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sunshine-workspace-test-',
    );
    final database = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}\\workspaces.sqlite',
    );
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    final first = _membership('workspace-one', 'Personal workspace');
    final second = _membership('workspace-two', 'Business workspace');
    final repository = WorkspaceRepository(
      dataSource: FakeWorkspaceDataSource([first, second]),
      localDatabase: database,
    );

    final initial = await repository.loadSnapshot();
    expect(initial.selectedWorkspace, isNull);
    await repository.selectWorkspace(second);
    final restored = await repository.loadSnapshot();
    expect(restored.selectedWorkspace?.workspaceId, 'workspace-two');

    final cached = WorkspaceMembership.fromCache(
      (await database.readCachedWorkspaces()).first,
    );
    expect(cached.authorizationVerified, isFalse);
    expect(
      () => repository.selectWorkspace(cached),
      throwsStateError,
    );
  });

  test('role permissions are centralized and Owner-only operations stay Owner-only',
      () {
    expect(
      WorkspaceRole.owner.grants(WorkspacePermission.deleteWorkspace),
      isTrue,
    );
    expect(
      WorkspaceRole.admin.grants(WorkspacePermission.manageMembers),
      isTrue,
    );
    expect(
      WorkspaceRole.admin.grants(WorkspacePermission.transferOwnership),
      isFalse,
    );
    expect(
      WorkspaceRole.manager.grants(WorkspacePermission.manageOperations),
      isTrue,
    );
    expect(
      WorkspaceRole.manager.grants(WorkspacePermission.manageMembers),
      isFalse,
    );
    for (final role in [WorkspaceRole.salesperson, WorkspaceRole.cashier]) {
      expect(role.grants(WorkspacePermission.createSales), isTrue);
      expect(role.grants(WorkspacePermission.limitedProductAccess), isTrue);
      expect(role.grants(WorkspacePermission.manageOperations), isFalse);
    }
    expect(() => WorkspaceRole.parse('Superuser'), throwsFormatException);
  });

  test('authentication cleanup preserves unrelated app metadata', () async {
    final database = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.writeMetadata('unrelated_setting', 'preserve-me');
    await database.writeSelectedWorkspaceId('workspace-id');
    await database.replaceCachedWorkspaces([
      _membership('workspace-id', 'Personal workspace').toCacheRecord(),
    ]);

    await database.clearAuthenticationLocalState();

    expect(await database.readMetadata('unrelated_setting'), 'preserve-me');
    expect(await database.readSelectedWorkspaceId(), isNull);
    expect(await database.readCachedWorkspaces(), isEmpty);
  });
}

WorkspaceMembership _membership(String id, String name) =>
    WorkspaceMembership.fromServer(
      workspaceId: id,
      name: name,
      type: id == 'workspace-one' ? 'personal' : 'business',
      ownerId: 'owner-id',
      role: 'Owner',
      verifiedAt: DateTime.utc(2026, 10, 31),
    );

final class FakeWorkspaceDataSource implements WorkspaceDataSource {
  FakeWorkspaceDataSource(this.memberships);

  final List<WorkspaceMembership> memberships;

  @override
  Future<List<WorkspaceMembership>> fetchMemberships() async => memberships;
}

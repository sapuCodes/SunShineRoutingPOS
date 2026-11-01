import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sunshinerpos/core/database/local_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'creates the initial schema and persists application metadata',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sunshine-pos-database-test-',
      );
      final databasePath = '${directory.path}\\test.sqlite';
      var database = await LocalDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      expect(await database.getSchemaVersion(), LocalDatabase.currentVersion);
      expect(await database.readMetadata('workspace_context'), isNull);
      await database.writeMetadata('workspace_context', 'unselected');
      await database.writeSelectedWorkspaceId('workspace-id');
      await database.replaceCachedWorkspaces([
        {
          'workspace_id': 'workspace-id',
          'name': 'Personal workspace',
          'type': 'personal',
          'owner_id': 'user-id',
          'role': 'Owner',
          'last_verified_at': '2026-10-31T12:00:00.000Z',
        },
      ]);
      expect(await database.readMetadata('workspace_context'), 'unselected');
      expect(await database.readSelectedWorkspaceId(), 'workspace-id');
      expect((await database.readCachedWorkspaces()).single['role'], 'Owner');
      await database.close();

      database = await LocalDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      expect(await database.readMetadata('workspace_context'), 'unselected');
      expect(await database.readSelectedWorkspaceId(), 'workspace-id');
      await database.clearAuthenticationLocalState();
      expect(await database.readMetadata('workspace_context'), 'unselected');
      expect(await database.readSelectedWorkspaceId(), isNull);
      expect(await database.readCachedWorkspaces(), isEmpty);
      await database.close();
    },
  );

  test('rejects empty metadata keys and use after close', () async {
    final database = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );

    await expectLater(database.readMetadata(' '), throwsArgumentError);
    await database.close();
    await expectLater(database.getSchemaVersion(), throwsStateError);
  });
}

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabase {
  LocalDatabase._(this._database);

  static const int currentVersion = 2;
  static const String _databaseFileName = 'sunshine_pos.sqlite';

  final Database _database;
  Future<void>? _closeFuture;

  static Future<LocalDatabase> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final selectedFactory = factory ?? await _platformDatabaseFactory();
    final selectedPath = databasePath ?? await _platformDatabasePath();
    final database = await selectedFactory.openDatabase(
      selectedPath,
      options: OpenDatabaseOptions(
        version: currentVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) => _runMigrations(database, 0, version),
        onUpgrade: _runMigrations,
      ),
    );

    return LocalDatabase._(database);
  }

  Future<int> getSchemaVersion() async {
    _ensureOpen();
    return _database.getVersion();
  }

  Future<String?> readMetadata(String key) async {
    _ensureOpen();
    _validateMetadataKey(key);
    final rows = await _database.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> writeMetadata(String key, String value) async {
    _ensureOpen();
    _validateMetadataKey(key);
    await _database.insert('app_metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> readSelectedWorkspaceId() =>
      readMetadata('selected_workspace_id');

  Future<void> writeSelectedWorkspaceId(String? workspaceId) async {
    if (workspaceId == null) {
      _ensureOpen();
      await _database.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['selected_workspace_id'],
      );
      return;
    }
    if (workspaceId.trim().isEmpty) {
      throw ArgumentError.value(
        workspaceId,
        'workspaceId',
        'Must not be empty.',
      );
    }
    await writeMetadata('selected_workspace_id', workspaceId);
  }

  Future<void> replaceCachedWorkspaces(
    List<Map<String, Object?>> workspaces,
  ) async {
    _ensureOpen();
    await _database.transaction((transaction) async {
      await transaction.delete('cached_workspaces');
      for (final workspace in workspaces) {
        await transaction.insert('cached_workspaces', workspace);
      }
    });
  }

  Future<List<Map<String, Object?>>> readCachedWorkspaces() async {
    _ensureOpen();
    final rows = await _database.query(
      'cached_workspaces',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Map<String, Object?>.from).toList(growable: false);
  }

  Future<void> clearAuthenticationLocalState() async {
    _ensureOpen();
    await _database.transaction((transaction) async {
      await transaction.delete('cached_workspaces');
      await transaction.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['selected_workspace_id'],
      );
    });
  }

  Future<void> close() => _closeFuture ??= _database.close();

  void _ensureOpen() {
    if (_closeFuture != null) {
      throw StateError('The local database has been closed.');
    }
  }

  static void _validateMetadataKey(String key) {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Must not be empty.');
    }
  }

  static Future<void> _runMigrations(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 1:
          await database.execute('''
            CREATE TABLE app_metadata (
              key TEXT PRIMARY KEY NOT NULL,
              value TEXT NOT NULL
            ) WITHOUT ROWID
          ''');
        case 2:
          await database.execute('''
            CREATE TABLE cached_workspaces (
              workspace_id TEXT PRIMARY KEY NOT NULL,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              owner_id TEXT NOT NULL,
              role TEXT NOT NULL,
              last_verified_at TEXT NOT NULL
            )
          ''');
        default:
          throw StateError('No local database migration exists for v$version.');
      }
    }
  }

  static Future<DatabaseFactory> _platformDatabaseFactory() async {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    if (Platform.isAndroid) {
      return sqflite.databaseFactory;
    }
    throw UnsupportedError(
      'Local SQLite is currently configured for Android and Windows.',
    );
  }

  static Future<String> _platformDatabasePath() async {
    if (Platform.isWindows) {
      final directory = await getApplicationSupportDirectory();
      return path.join(directory.path, _databaseFileName);
    }
    if (Platform.isAndroid) {
      final directory = await sqflite.getDatabasesPath();
      return path.join(directory, _databaseFileName);
    }
    throw UnsupportedError(
      'Local SQLite is currently configured for Android and Windows.',
    );
  }
}

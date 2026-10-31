import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabase {
  LocalDatabase._(this._database);

  static const int currentVersion = 1;
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

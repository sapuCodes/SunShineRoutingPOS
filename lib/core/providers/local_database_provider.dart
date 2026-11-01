import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/local_database.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw StateError('The local database must be provided during app startup.');
});

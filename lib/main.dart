import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';

import 'app/sunshine_pos_app.dart';
import 'core/database/local_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_launchApplication());
}

Future<void> _launchApplication() async {
  try {
    final database = await LocalDatabase.open();
    runApp(SunShinePosApp(database: database));
  } catch (error, stackTrace) {
    log(
      'Could not initialize local storage.',
      error: error,
      stackTrace: stackTrace,
    );
    runApp(DatabaseStartupErrorApp(error: error, onRetry: _launchApplication));
  }
}

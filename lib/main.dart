import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_config.dart';
import 'app/sunshine_pos_app.dart';
import 'core/database/local_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_launchApplication());
}

Future<void> _launchApplication() async {
  late final LocalDatabase database;
  try {
    database = await LocalDatabase.open();
  } catch (error, stackTrace) {
    log(
      'Could not initialize local storage.',
      error: error,
      stackTrace: stackTrace,
    );
    runApp(DatabaseStartupErrorApp(error: error, onRetry: _launchApplication));
    return;
  }

  AppConfig config;
  Object? startupError;
  try {
    config = AppConfig.fromEnvironment();
  } catch (error, stackTrace) {
    log(
      'Could not read application configuration.',
      error: error,
      stackTrace: stackTrace,
    );
    config = const AppConfig();
    startupError = error;
  }

  SupabaseClient? supabaseClient;
  if (startupError == null && config.hasSupabaseConfiguration) {
    try {
      await Supabase.initialize(
        url: config.supabaseUrl.trim(),
        publishableKey: config.supabasePublishableKey.trim(),
      );
      supabaseClient = Supabase.instance.client;
    } catch (error, stackTrace) {
      log(
        'Could not initialize local Supabase.',
        error: error,
        stackTrace: stackTrace,
      );
      startupError = error;
    }
  }

  runApp(
    SunShinePosApp(
      database: database,
      config: config,
      supabaseClient: supabaseClient,
      supabaseStartupError: startupError,
    ),
  );
}

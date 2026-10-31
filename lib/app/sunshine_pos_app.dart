import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';
import '../core/providers/app_providers.dart';
import 'app_theme.dart';

class SunShinePosApp extends StatelessWidget {
  const SunShinePosApp({required this.database, super.key});

  final LocalDatabase database;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(database.close()));
          return database;
        }),
      ],
      child: const _RoutedApplication(),
    );
  }
}

class DatabaseStartupErrorApp extends StatelessWidget {
  const DatabaseStartupErrorApp({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sun Shine POS',
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage, color: AppColors.orange, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Could not open local storage.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => unawaited(onRetry()),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutedApplication extends ConsumerWidget {
  const _RoutedApplication();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localDatabaseProvider);
    return MaterialApp.router(
      title: 'Sun Shine POS',
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

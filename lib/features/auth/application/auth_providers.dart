import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/local_database_provider.dart';
import '../data/auth_gateway.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final supabaseStartupErrorProvider = Provider<Object?>((ref) => null);

final authGatewayProvider = Provider<AuthGateway?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return SupabaseAuthGateway(client, ref.watch(localDatabaseProvider));
});

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<AuthIdentity?>>(
      AuthController.new,
    );

class AuthController extends Notifier<AsyncValue<AuthIdentity?>> {
  StreamSubscription<AuthIdentity?>? _subscription;

  @override
  AsyncValue<AuthIdentity?> build() {
    final gateway = ref.watch(authGatewayProvider);
    if (gateway == null) {
      return const AsyncData(null);
    }
    _subscription = gateway.identityChanges.listen(
      (identity) => state = AsyncData(identity),
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return AsyncData(gateway.currentIdentity);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _requireGateway().register(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _requireGateway().signIn(email: email, password: password);
    state = AsyncData(_requireGateway().currentIdentity);
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _requireGateway().verifyEmail(email: email, code: code);
    state = AsyncData(_requireGateway().currentIdentity);
  }

  Future<void> resendVerificationCode({required String email}) =>
      _requireGateway().resendVerificationCode(email: email);

  Future<void> requestPasswordReset({required String email}) =>
      _requireGateway().requestPasswordReset(email: email);

  Future<void> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _requireGateway().completePasswordReset(
      email: email,
      code: code,
      newPassword: newPassword,
    );
    state = AsyncData(_requireGateway().currentIdentity);
  }

  Future<void> signOut() async {
    await _requireGateway().signOut();
    state = const AsyncData(null);
  }

  AuthGateway _requireGateway() {
    final gateway = ref.read(authGatewayProvider);
    if (gateway == null) {
      throw StateError('Local Supabase configuration is required.');
    }
    return gateway;
  }
}

final authRouterRefreshProvider = Provider<ChangeNotifier>((ref) {
  final refresh = _AuthRouterRefresh(ref.watch(authGatewayProvider));
  ref.onDispose(refresh.dispose);
  return refresh;
});

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(AuthGateway? gateway) {
    if (gateway != null) {
      _subscription = gateway.identityChanges.listen(
        (_) => notifyListeners(),
        onError: (Object error, StackTrace stackTrace) => notifyListeners(),
      );
    }
  }

  StreamSubscription<AuthIdentity?>? _subscription;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

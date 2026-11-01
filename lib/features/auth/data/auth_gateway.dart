import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/local_database.dart';

final class AuthIdentity {
  const AuthIdentity({
    required this.userId,
    required this.email,
    required this.emailVerified,
  });

  factory AuthIdentity.fromSession(Session? session) {
    final user = session?.user;
    if (user == null) {
      throw StateError('A session without a user cannot be an identity.');
    }
    return AuthIdentity(
      userId: user.id,
      email: user.email ?? '',
      emailVerified: user.emailConfirmedAt != null,
    );
  }

  static AuthIdentity? fromOptionalSession(Session? session) =>
      session == null ? null : AuthIdentity.fromSession(session);

  final String userId;
  final String email;
  final bool emailVerified;
}

abstract interface class AuthGateway {
  AuthIdentity? get currentIdentity;
  Stream<AuthIdentity?> get identityChanges;

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> signIn({required String email, required String password});
  Future<void> verifyEmail({required String email, required String code});
  Future<void> resendVerificationCode({required String email});
  Future<void> requestPasswordReset({required String email});
  Future<void> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
  Future<void> signOut();
}

final class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client, this._localDatabase);

  final SupabaseClient _client;
  final LocalDatabase _localDatabase;

  @override
  AuthIdentity? get currentIdentity =>
      AuthIdentity.fromOptionalSession(_client.auth.currentSession);

  @override
  Stream<AuthIdentity?> get identityChanges =>
      _client.auth.onAuthStateChange.map(
        (state) => AuthIdentity.fromOptionalSession(state.session),
      );

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    if (response.user == null) {
      throw StateError('Registration did not return an authentication user.');
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null || user.emailConfirmedAt == null) {
      await _client.auth.signOut();
      throw StateError('Verify your email address before signing in.');
    }
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: code,
    );
    if (response.session == null ||
        response.user?.emailConfirmedAt == null) {
      throw StateError('Email verification did not create a verified session.');
    }
  }

  @override
  Future<void> resendVerificationCode({required String email}) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _client.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: code,
    );
    if (response.session == null) {
      throw StateError('Password reset verification did not create a session.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _localDatabase.clearAuthenticationLocalState();
  }
}

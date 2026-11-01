import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunshinerpos/features/auth/application/auth_providers.dart';
import 'package:sunshinerpos/features/auth/data/auth_gateway.dart';

void main() {
  test('restores a previously persisted verified identity', () async {
    final gateway = FakeAuthGateway(
      currentIdentity: const AuthIdentity(
        userId: 'user-id',
        email: 'user@example.test',
        emailVerified: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });

    final restored = container.read(authControllerProvider).requireValue;
    expect(restored?.userId, 'user-id');
    expect(restored?.emailVerified, isTrue);
  });

  test('sign-in, verification, reset, and sign-out update auth state', () async {
    final gateway = FakeAuthGateway();
    final container = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });

    final controller = container.read(authControllerProvider.notifier);
    await controller.signIn(
      email: 'user@example.test',
      password: 'a-short-existing-password',
    );
    expect(container.read(authControllerProvider).requireValue?.emailVerified,
        isTrue);

    await controller.signOut();
    expect(container.read(authControllerProvider).requireValue, isNull);

    await controller.verifyEmail(email: 'new@example.test', code: '123456');
    expect(gateway.verifiedEmail, 'new@example.test');
    expect(container.read(authControllerProvider).requireValue?.emailVerified,
        isTrue);

    await controller.requestPasswordReset(email: 'user@example.test');
    await controller.completePasswordReset(
      email: 'user@example.test',
      code: '654321',
      newPassword: 'new-password-123',
    );
    expect(gateway.passwordResetEmail, 'user@example.test');
    expect(gateway.completedResetCode, '654321');
  });

  test('authentication failures are propagated and do not create a session', () async {
    final gateway = FakeAuthGateway(failSignIn: true);
    final container = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });

    await expectLater(
      container.read(authControllerProvider.notifier).signIn(
            email: 'user@example.test',
            password: 'wrong-password',
          ),
      throwsStateError,
    );
    expect(container.read(authControllerProvider).requireValue, isNull);
  });
}

final class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.currentIdentity, this.failSignIn = false});

  final StreamController<AuthIdentity?> _changes =
      StreamController<AuthIdentity?>.broadcast(sync: true);
  final bool failSignIn;
  @override
  AuthIdentity? currentIdentity;
  String? verifiedEmail;
  String? passwordResetEmail;
  String? completedResetCode;

  @override
  Stream<AuthIdentity?> get identityChanges => _changes.stream;

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (failSignIn) {
      throw StateError('Authentication failed.');
    }
    _emit(const AuthIdentity(
      userId: 'user-id',
      email: 'user@example.test',
      emailVerified: true,
    ));
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    verifiedEmail = email;
    _emit(AuthIdentity(userId: 'new-user-id', email: email, emailVerified: true));
  }

  @override
  Future<void> resendVerificationCode({required String email}) async {}

  @override
  Future<void> requestPasswordReset({required String email}) async {
    passwordResetEmail = email;
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    completedResetCode = code;
  }

  @override
  Future<void> signOut() async => _emit(null);

  void _emit(AuthIdentity? identity) {
    currentIdentity = identity;
    _changes.add(identity);
  }

  Future<void> close() => _changes.close();
}

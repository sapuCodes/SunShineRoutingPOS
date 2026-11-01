import 'package:flutter_test/flutter_test.dart';
import 'package:sunshinerpos/features/auth/domain/auth_form_validation.dart';

void main() {
  test('registration validates name, email, password, and email code', () {
    expect(AuthFormValidation.displayName('Asha Perera'), isNull);
    expect(AuthFormValidation.email('asha@example.test'), isNull);
    expect(AuthFormValidation.password('strong-pass-123'), isNull);
    expect(AuthFormValidation.verificationCode('123456'), isNull);

    expect(AuthFormValidation.displayName(' '), isNotNull);
    expect(AuthFormValidation.email('not-an-email'), isNotNull);
    expect(AuthFormValidation.password('short'), isNotNull);
    expect(AuthFormValidation.verificationCode('12ab56'), isNotNull);
  });

  test('sign in accepts existing passwords shorter than registration minimum', () {
    expect(AuthFormValidation.signInPassword('short'), isNull);
    expect(AuthFormValidation.signInPassword(''), isNotNull);
  });
}

abstract final class AuthFormValidation {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your email address.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  static String? signInPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Enter your name.';
    }
    if (name.length > 120) {
      return 'Use no more than 120 characters.';
    }
    return null;
  }

  static String? verificationCode(String? value) {
    if (value == null || !RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Enter the 6-digit code from your email.';
    }
    return null;
  }
}

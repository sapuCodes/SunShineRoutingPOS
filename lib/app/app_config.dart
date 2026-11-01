enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({
    this.environment = AppEnvironment.development,
    this.defaultCountryCode = 'LK',
    this.defaultCurrencyCode = 'LKR',
    this.defaultTimezone = 'Asia/Colombo',
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
  });

  factory AppConfig.fromEnvironment() {
    final environmentName = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    final environment = AppEnvironment.values.where(
      (value) => value.name == environmentName,
    );
    if (environment.isEmpty) {
      throw FormatException('Unknown APP_ENV value: $environmentName');
    }

    return AppConfig(
      environment: environment.first,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
    );
  }

  final AppEnvironment environment;
  final String defaultCountryCode;
  final String defaultCurrencyCode;
  final String defaultTimezone;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get hasSupabaseConfiguration =>
      _isLocalSupabaseUrl(supabaseUrl) &&
      supabasePublishableKey.trim().startsWith('sb_publishable_');

  bool _isLocalSupabaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.port != 54321 ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return false;
    }

    return const {'127.0.0.1', 'localhost', '10.0.2.2'}
        .contains(uri.host.toLowerCase());
  }
}

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
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;
}

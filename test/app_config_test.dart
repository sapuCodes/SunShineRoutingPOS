import 'package:flutter_test/flutter_test.dart';
import 'package:sunshinerpos/app/app_config.dart';

void main() {
  test('configuration provides the approved locale defaults', () {
    const config = AppConfig();

    expect(config.environment, AppEnvironment.development);
    expect(config.defaultCountryCode, 'LK');
    expect(config.defaultCurrencyCode, 'LKR');
    expect(config.defaultTimezone, 'Asia/Colombo');
    expect(config.hasSupabaseConfiguration, isFalse);
  });

  test('Supabase configuration requires both public client values', () {
    const config = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'public-client-key',
    );

    expect(config.hasSupabaseConfiguration, isTrue);
  });
}

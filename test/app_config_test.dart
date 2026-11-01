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

  test('Supabase configuration requires a local URL and public client key', () {
    const config = AppConfig(
      supabaseUrl: 'http://127.0.0.1:54321',
      supabasePublishableKey: 'sb_publishable_test_key',
    );

    expect(config.hasSupabaseConfiguration, isTrue);
  });

  test('allows the Android emulator host for local Supabase', () {
    const config = AppConfig(
      supabaseUrl: 'http://10.0.2.2:54321',
      supabasePublishableKey: 'sb_publishable_test_key',
    );

    expect(config.hasSupabaseConfiguration, isTrue);
  });

  test('rejects hosted URLs and unexpected local ports', () {
    for (final url in [
      'https://project.supabase.co',
      'http://127.0.0.1:54322',
    ]) {
      final config = AppConfig(
        supabaseUrl: url,
        supabasePublishableKey: 'sb_publishable_test_key',
      );
      expect(config.hasSupabaseConfiguration, isFalse, reason: url);
    }
  });

  test('rejects non-publishable keys even with a local URL', () {
    const config = AppConfig(
      supabaseUrl: 'http://127.0.0.1:54321',
      supabasePublishableKey: 'service-role-key',
    );

    expect(config.hasSupabaseConfiguration, isFalse);
  });
}

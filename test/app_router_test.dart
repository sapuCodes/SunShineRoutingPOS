import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunshinerpos/core/providers/app_providers.dart';

void main() {
  test('dashboard is registered as a named application route', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);

    expect(router.namedLocation('dashboard'), '/dashboard');
  });
}

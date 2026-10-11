import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';

import 'fake_checklister_gateway.dart';

void main() {
  test('default gateway is inert: Checklister reported not installed', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(checklisterInstalledProvider.future), isFalse);
  });

  test('checklisterInstalledProvider follows the overridden gateway', () async {
    final c = ProviderContainer(
      overrides: [checklisterGatewayProvider.overrideWithValue(FakeChecklisterGateway(installed: true))],
    );
    addTearDown(c.dispose);
    expect(await c.read(checklisterInstalledProvider.future), isTrue);
  });
}

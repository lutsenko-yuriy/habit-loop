import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';

import 'fake_remote_config_service.dart';
import 'test_remote_config_defaults.dart';

void main() {
  group('TestRemoteConfigDefaults', () {
    test('every key exists in RemoteConfigDefaults.all', () {
      for (final key in TestRemoteConfigDefaults.all.keys) {
        expect(RemoteConfigDefaults.all.containsKey(key), isTrue, reason: 'unknown RC key: $key');
      }
    });

    test('every value has the same runtime type as the production default', () {
      TestRemoteConfigDefaults.all.forEach((key, value) {
        final productionValue = RemoteConfigDefaults.all[key];
        expect(value.runtimeType, productionValue.runtimeType, reason: 'type mismatch for $key');
      });
    });
  });

  group('FakeRemoteConfigService.withTestDefaults', () {
    test('applies test defaults when no override is given', () {
      final service = FakeRemoteConfigService.withTestDefaults();

      expect(service.getBool('display_name_personalization_enabled'), isFalse);
    });

    test('caller overrides win over test defaults', () {
      final service = FakeRemoteConfigService.withTestDefaults(
        overrides: {'display_name_personalization_enabled': true},
      );

      expect(service.getBool('display_name_personalization_enabled'), isTrue);
    });

    test('falls back to production defaults for keys with no test default', () {
      final service = FakeRemoteConfigService.withTestDefaults();

      expect(service.getInt('max_active_pacts'), RemoteConfigDefaults.maxActivePacts);
    });

    test('bare constructor still returns production defaults, unaffected by test defaults', () {
      final service = FakeRemoteConfigService();

      expect(service.getBool('display_name_personalization_enabled'), isTrue);
    });

    test('each construction builds an independent map — no aliasing between instances', () {
      final a = FakeRemoteConfigService.withTestDefaults();
      final b = FakeRemoteConfigService.withTestDefaults();

      a.overrides['display_name_personalization_enabled'] = true;

      expect(b.getBool('display_name_personalization_enabled'), isFalse);
    });
  });
}

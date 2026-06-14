import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/feature_flags.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';

import 'fake_remote_config_service.dart';

void main() {
  group('FeatureFlags', () {
    group('fromRemoteConfig', () {
      test('languageSelectionEnabled defaults to true', () {
        final rc = FakeRemoteConfigService();
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.languageSelectionEnabled, isTrue);
      });

      test('networkSyncEnabled defaults to true', () {
        final rc = FakeRemoteConfigService();
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.networkSyncEnabled, isTrue);
      });

      test('languageSelectionEnabled reads false from RC override', () {
        final rc = FakeRemoteConfigService(overrides: {'language_selection_enabled': false});
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.languageSelectionEnabled, isFalse);
      });

      test('networkSyncEnabled reads false from RC override', () {
        final rc = FakeRemoteConfigService(overrides: {'network_sync_enabled': false});
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.networkSyncEnabled, isFalse);
      });

      test('default values match RemoteConfigDefaults constants', () {
        final rc = FakeRemoteConfigService();
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.languageSelectionEnabled, RemoteConfigDefaults.languageSelectionEnabled);
        expect(flags.networkSyncEnabled, RemoteConfigDefaults.networkSyncEnabled);
      });
    });

    group('equality', () {
      test('two instances with same values are equal', () {
        final rc = FakeRemoteConfigService();
        final a = FeatureFlags.fromRemoteConfig(rc);
        final b = FeatureFlags.fromRemoteConfig(rc);
        expect(a, equals(b));
      });

      test('same hashCode for equal instances', () {
        final rc = FakeRemoteConfigService();
        final a = FeatureFlags.fromRemoteConfig(rc);
        final b = FeatureFlags.fromRemoteConfig(rc);
        expect(a.hashCode, b.hashCode);
      });

      test('instances differ when flags differ', () {
        final rcAll = FakeRemoteConfigService();
        final rcOff = FakeRemoteConfigService(overrides: {'language_selection_enabled': false});
        expect(FeatureFlags.fromRemoteConfig(rcAll), isNot(equals(FeatureFlags.fromRemoteConfig(rcOff))));
      });
    });
  });
}

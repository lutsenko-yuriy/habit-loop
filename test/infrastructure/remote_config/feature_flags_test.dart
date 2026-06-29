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

      test('pactTimelineEnabled defaults to true', () {
        final rc = FakeRemoteConfigService();
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.pactTimelineEnabled, isTrue);
      });

      test('pactTimelineEnabled reads false from RC override', () {
        final rc = FakeRemoteConfigService(overrides: {'pact_timeline_enabled': false});
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.pactTimelineEnabled, isFalse);
      });

      test('showupRedemptionEnabled defaults to true', () {
        final rc = FakeRemoteConfigService();
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.showupRedemptionEnabled, isTrue);
      });

      test('showupRedemptionEnabled reads false from RC override', () {
        final rc = FakeRemoteConfigService(overrides: {'showup_redemption_enabled': false});
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.showupRedemptionEnabled, isFalse);
      });

      test('default values match RemoteConfigDefaults constants', () {
        final rc = FakeRemoteConfigService();
        final flags = FeatureFlags.fromRemoteConfig(rc);
        expect(flags.languageSelectionEnabled, RemoteConfigDefaults.languageSelectionEnabled);
        expect(flags.networkSyncEnabled, RemoteConfigDefaults.networkSyncEnabled);
        expect(flags.pactTimelineEnabled, RemoteConfigDefaults.pactTimelineEnabled);
        expect(flags.showupRedemptionEnabled, RemoteConfigDefaults.showupRedemptionEnabled);
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

      test('instances differ when language_selection_enabled differs', () {
        final rcAll = FakeRemoteConfigService();
        final rcOff = FakeRemoteConfigService(overrides: {'language_selection_enabled': false});
        expect(FeatureFlags.fromRemoteConfig(rcAll), isNot(equals(FeatureFlags.fromRemoteConfig(rcOff))));
      });

      test('instances differ when pact_timeline_enabled differs', () {
        final rcAll = FakeRemoteConfigService();
        final rcOff = FakeRemoteConfigService(overrides: {'pact_timeline_enabled': false});
        expect(FeatureFlags.fromRemoteConfig(rcAll), isNot(equals(FeatureFlags.fromRemoteConfig(rcOff))));
      });

      test('instances differ when showup_redemption_enabled differs', () {
        final rcAll = FakeRemoteConfigService();
        final rcOff = FakeRemoteConfigService(overrides: {'showup_redemption_enabled': false});
        expect(FeatureFlags.fromRemoteConfig(rcAll), isNot(equals(FeatureFlags.fromRemoteConfig(rcOff))));
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_config.dart';

import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

void main() {
  group('PactTimelineConfig.fromRemoteConfig', () {
    group('enabled', () {
      test('defaults to true', () {
        final config = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
        expect(config.enabled, isTrue);
      });

      test('reads false from RC override', () {
        final rc = FakeRemoteConfigService(overrides: {'pact_timeline_enabled': false});
        expect(PactTimelineConfig.fromRemoteConfig(rc).enabled, isFalse);
      });
    });

    group('noGroupingTailPeriodInDays', () {
      test('defaults to 7', () {
        final config = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
        expect(config.noGroupingTailPeriodInDays, 7);
      });

      test('reads custom value from RC', () {
        final rc = FakeRemoteConfigService(overrides: {'pact_timeline_no_grouping_tail_period_in_days': 15});
        expect(PactTimelineConfig.fromRemoteConfig(rc).noGroupingTailPeriodInDays, 15);
      });
    });
  });

  group('PactTimelineConfig equality', () {
    test('two instances with same values are equal', () {
      final a = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
      final b = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
      expect(a, equals(b));
    });

    test('same hashCode for equal instances', () {
      final a = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
      final b = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
      expect(a.hashCode, b.hashCode);
    });

    test('instances differ when enabled differs', () {
      final on = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
      final off = PactTimelineConfig.fromRemoteConfig(
        FakeRemoteConfigService(overrides: {'pact_timeline_enabled': false}),
      );
      expect(on, isNot(equals(off)));
    });

    test('instances differ when tail period differs', () {
      final a = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
      final b = PactTimelineConfig.fromRemoteConfig(
        FakeRemoteConfigService(overrides: {
          'pact_timeline_no_grouping_tail_period_in_days': 5,
        }),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('PactTimelineConfig const constructor', () {
    test('fields are set correctly', () {
      const config = PactTimelineConfig(
        enabled: true,
        noGroupingTailPeriodInDays: 4,
      );
      expect(config.enabled, isTrue);
      expect(config.noGroupingTailPeriodInDays, 4);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
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

    group('milestoneGroupingThreshold', () {
      test('defaults to 10', () {
        final config = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
        expect(config.milestoneGroupingThreshold, 10);
      });

      test('reads custom value from RC', () {
        final rc = FakeRemoteConfigService(overrides: {'pact_timeline_milestone_grouping_threshold': 5});
        expect(PactTimelineConfig.fromRemoteConfig(rc).milestoneGroupingThreshold, 5);
      });

      test('default matches RemoteConfigDefaults constant', () {
        final config = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
        expect(config.milestoneGroupingThreshold, RemoteConfigDefaults.pactTimelineMilestoneGroupingThreshold);
      });
    });

    group('noGroupingTailSize', () {
      test('defaults to 10', () {
        final config = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
        expect(config.noGroupingTailSize, 10);
      });

      test('reads custom value from RC', () {
        final rc = FakeRemoteConfigService(overrides: {'pact_timeline_no_grouping_tail_size': 15});
        expect(PactTimelineConfig.fromRemoteConfig(rc).noGroupingTailSize, 15);
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

    test('instances differ when threshold differs', () {
      final a = PactTimelineConfig.fromRemoteConfig(FakeRemoteConfigService());
      final b = PactTimelineConfig.fromRemoteConfig(
        FakeRemoteConfigService(overrides: {
          'pact_timeline_milestone_grouping_threshold': 5,
          'pact_timeline_no_grouping_tail_size': 5,
        }),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('PactTimelineConfig const constructor', () {
    test('fields are set correctly', () {
      const config = PactTimelineConfig(
        enabled: true,
        milestoneGroupingThreshold: 8,
        noGroupingTailSize: 4,
      );
      expect(config.enabled, isTrue);
      expect(config.milestoneGroupingThreshold, 8);
      expect(config.noGroupingTailSize, 4);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';

void main() {
  group('RemoteConfigDefaults', () {
    group('max_active_pacts', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('max_active_pacts'), isTrue);
      });

      test('appears in intRanges with correct bounds', () {
        expect(RemoteConfigDefaults.intRanges['max_active_pacts'], (min: 1, max: 10));
      });
    });

    group('sync_max_consecutive_failures', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('sync_max_consecutive_failures'), isTrue);
      });

      test('default value is 5', () {
        expect(RemoteConfigDefaults.all['sync_max_consecutive_failures'], 5);
      });

      test('constant matches all map value', () {
        expect(RemoteConfigDefaults.syncMaxConsecutiveFailures,
            equals(RemoteConfigDefaults.all['sync_max_consecutive_failures']));
      });

      test('is absent from allowedValues (free-text integer field)', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('sync_max_consecutive_failures'), isFalse);
      });
    });

    group('debug_connectivity_state', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('debug_connectivity_state'), isTrue);
      });

      test('default value is perfect', () {
        expect(RemoteConfigDefaults.all['debug_connectivity_state'], 'perfect');
      });

      test('constant matches all map value', () {
        expect(
            RemoteConfigDefaults.debugConnectivityState, equals(RemoteConfigDefaults.all['debug_connectivity_state']));
      });

      test('appears in allowedValues with the three allowed states', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('debug_connectivity_state'), isTrue);
        expect(
          RemoteConfigDefaults.allowedValues['debug_connectivity_state'],
          containsAll(['perfect', 'absent', 'unstable']),
        );
      });
    });

    group('debug_connectivity_stability_percent', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('debug_connectivity_stability_percent'), isTrue);
      });

      test('default value is 100', () {
        expect(RemoteConfigDefaults.all['debug_connectivity_stability_percent'], 100);
      });

      test('constant matches all map value', () {
        expect(RemoteConfigDefaults.debugConnectivityStabilityPercent,
            equals(RemoteConfigDefaults.all['debug_connectivity_stability_percent']));
      });

      test('is absent from allowedValues (free-text integer field)', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('debug_connectivity_stability_percent'), isFalse);
      });
    });

    group('language_selection_enabled', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('language_selection_enabled'), isTrue);
      });

      test('default value is true', () {
        expect(RemoteConfigDefaults.all['language_selection_enabled'], isTrue);
      });

      test('constant matches all map value', () {
        expect(RemoteConfigDefaults.languageSelectionEnabled,
            equals(RemoteConfigDefaults.all['language_selection_enabled']));
      });

      test('appears in allowedValues with true/false options', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('language_selection_enabled'), isTrue);
        expect(RemoteConfigDefaults.allowedValues['language_selection_enabled'], containsAll(['true', 'false']));
      });

      test('is absent from intRanges (boolean, not int-bounded)', () {
        expect(RemoteConfigDefaults.intRanges.containsKey('language_selection_enabled'), isFalse);
      });
    });

    group('network_sync_enabled', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('network_sync_enabled'), isTrue);
      });

      test('default value is true', () {
        expect(RemoteConfigDefaults.all['network_sync_enabled'], isTrue);
      });

      test('constant matches all map value', () {
        expect(RemoteConfigDefaults.networkSyncEnabled, equals(RemoteConfigDefaults.all['network_sync_enabled']));
      });

      test('appears in allowedValues with true/false options', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('network_sync_enabled'), isTrue);
        expect(RemoteConfigDefaults.allowedValues['network_sync_enabled'], containsAll(['true', 'false']));
      });

      test('is absent from intRanges (boolean, not int-bounded)', () {
        expect(RemoteConfigDefaults.intRanges.containsKey('network_sync_enabled'), isFalse);
      });
    });

    group('pact_timeline_enabled', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('pact_timeline_enabled'), isTrue);
      });

      test('default value is true', () {
        expect(RemoteConfigDefaults.all['pact_timeline_enabled'], isTrue);
      });

      test('constant matches all map value', () {
        expect(RemoteConfigDefaults.pactTimelineEnabled, equals(RemoteConfigDefaults.all['pact_timeline_enabled']));
      });

      test('appears in featureToggleKeys', () {
        expect(RemoteConfigDefaults.featureToggleKeys.contains('pact_timeline_enabled'), isTrue);
      });

      test('appears in allowedValues with true/false options', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('pact_timeline_enabled'), isTrue);
        expect(RemoteConfigDefaults.allowedValues['pact_timeline_enabled'], containsAll(['true', 'false']));
      });
    });

    group('showup_redemption_enabled', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('showup_redemption_enabled'), isTrue);
      });

      test('default value is true', () {
        expect(RemoteConfigDefaults.all['showup_redemption_enabled'], isTrue);
      });

      test('constant matches all map value', () {
        expect(RemoteConfigDefaults.showupRedemptionEnabled,
            equals(RemoteConfigDefaults.all['showup_redemption_enabled']));
      });

      test('appears in featureToggleKeys', () {
        expect(RemoteConfigDefaults.featureToggleKeys.contains('showup_redemption_enabled'), isTrue);
      });

      test('appears in allowedValues with true/false options', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('showup_redemption_enabled'), isTrue);
        expect(RemoteConfigDefaults.allowedValues['showup_redemption_enabled'], containsAll(['true', 'false']));
      });
    });

    group('pact_timeline_no_grouping_tail_period_in_days', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('pact_timeline_no_grouping_tail_period_in_days'), isTrue);
      });

      test('default value is 7', () {
        expect(RemoteConfigDefaults.all['pact_timeline_no_grouping_tail_period_in_days'], 7);
      });

      test('constant matches all map value', () {
        expect(
          RemoteConfigDefaults.pactTimelineNoGroupingTailPeriodInDays,
          equals(RemoteConfigDefaults.all['pact_timeline_no_grouping_tail_period_in_days']),
        );
      });

      test('appears in intRanges with correct bounds', () {
        expect(RemoteConfigDefaults.intRanges['pact_timeline_no_grouping_tail_period_in_days'], (min: 7, max: 21));
      });
    });
  });
}

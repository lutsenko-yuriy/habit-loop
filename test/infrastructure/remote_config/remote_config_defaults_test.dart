import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';

void main() {
  group('RemoteConfigDefaults', () {
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

      test('appears in allowedValues as null (free-value integer field)', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('sync_max_consecutive_failures'), isTrue);
        expect(RemoteConfigDefaults.allowedValues['sync_max_consecutive_failures'], isNull);
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

      test('appears in allowedValues as null (free-value integer field)', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('debug_connectivity_stability_percent'), isTrue);
        expect(RemoteConfigDefaults.allowedValues['debug_connectivity_stability_percent'], isNull);
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

      test('appears in intRanges as null (boolean, not int-bounded)', () {
        expect(RemoteConfigDefaults.intRanges.containsKey('language_selection_enabled'), isTrue);
        expect(RemoteConfigDefaults.intRanges['language_selection_enabled'], isNull);
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

      test('appears in intRanges as null (boolean, not int-bounded)', () {
        expect(RemoteConfigDefaults.intRanges.containsKey('network_sync_enabled'), isTrue);
        expect(RemoteConfigDefaults.intRanges['network_sync_enabled'], isNull);
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

    group('pact_timeline_milestone_grouping_threshold', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('pact_timeline_milestone_grouping_threshold'), isTrue);
      });

      test('default value is 10', () {
        expect(RemoteConfigDefaults.all['pact_timeline_milestone_grouping_threshold'], 10);
      });

      test('constant matches all map value', () {
        expect(
          RemoteConfigDefaults.pactTimelineMilestoneGroupingThreshold,
          equals(RemoteConfigDefaults.all['pact_timeline_milestone_grouping_threshold']),
        );
      });

      test('appears in allowedValues as null (free-value integer field)', () {
        expect(RemoteConfigDefaults.allowedValues.containsKey('pact_timeline_milestone_grouping_threshold'), isTrue);
        expect(RemoteConfigDefaults.allowedValues['pact_timeline_milestone_grouping_threshold'], isNull);
      });
    });

    group('pact_timeline_no_grouping_tail_size', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('pact_timeline_no_grouping_tail_size'), isTrue);
      });

      test('default sentinel value is 0', () {
        expect(RemoteConfigDefaults.all['pact_timeline_no_grouping_tail_size'], 0);
      });

      test('constant matches all map value', () {
        expect(
          RemoteConfigDefaults.pactTimelineNoGroupingTailSize,
          equals(RemoteConfigDefaults.all['pact_timeline_no_grouping_tail_size']),
        );
      });
    });

    group('pact_timeline_first_page_size', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('pact_timeline_first_page_size'), isTrue);
      });

      test('default sentinel value is 0', () {
        expect(RemoteConfigDefaults.all['pact_timeline_first_page_size'], 0);
      });

      test('constant matches all map value', () {
        expect(
          RemoteConfigDefaults.pactTimelineFirstPageSize,
          equals(RemoteConfigDefaults.all['pact_timeline_first_page_size']),
        );
      });
    });

    group('pact_timeline_nth_page_size', () {
      test('key exists in all map', () {
        expect(RemoteConfigDefaults.all.containsKey('pact_timeline_nth_page_size'), isTrue);
      });

      test('default sentinel value is 0', () {
        expect(RemoteConfigDefaults.all['pact_timeline_nth_page_size'], 0);
      });

      test('constant matches all map value', () {
        expect(
          RemoteConfigDefaults.pactTimelineNthPageSize,
          equals(RemoteConfigDefaults.all['pact_timeline_nth_page_size']),
        );
      });
    });
  });
}

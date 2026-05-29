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
  });
}

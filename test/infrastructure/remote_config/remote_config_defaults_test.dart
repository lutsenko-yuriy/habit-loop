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
  });
}

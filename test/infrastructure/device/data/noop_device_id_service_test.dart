import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/device/data/noop_device_id_service.dart';

void main() {
  group('NoopDeviceIdService', () {
    test('returns the sentinel device ID', () async {
      final id = await NoopDeviceIdService().getOrCreateDeviceId();
      expect(id, equals(NoopDeviceIdService.sentinelId));
    });

    test('never throws', () async {
      await expectLater(NoopDeviceIdService().getOrCreateDeviceId(), completes);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/device/data/shared_preferences_device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesDeviceIdService', () {
    test('generates a UUID on first call', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesDeviceIdService(prefs);

      final id = await service.getOrCreateDeviceId();

      expect(id, isNotEmpty);
      expect(id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('returns the same ID on subsequent calls', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesDeviceIdService(prefs);

      final id1 = await service.getOrCreateDeviceId();
      final id2 = await service.getOrCreateDeviceId();

      expect(id1, equals(id2));
    });

    test('persists the ID across service instances sharing the same prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final id1 = await SharedPreferencesDeviceIdService(prefs).getOrCreateDeviceId();
      final id2 = await SharedPreferencesDeviceIdService(prefs).getOrCreateDeviceId();

      expect(id1, equals(id2));
    });

    test('generates a different ID after the key is cleared', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesDeviceIdService(prefs);

      final id1 = await service.getOrCreateDeviceId();
      await prefs.remove(SharedPreferencesDeviceIdService.prefsKey);
      final id2 = await service.getOrCreateDeviceId();

      expect(id1, isNot(equals(id2)));
    });

    test('never throws', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesDeviceIdService(prefs);
      await expectLater(service.getOrCreateDeviceId(), completes);
    });
  });
}

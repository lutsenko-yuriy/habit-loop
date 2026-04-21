import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/remote_config/domain/remote_config_defaults.dart';

void main() {
  late NoopRemoteConfigService service;

  setUp(() {
    service = NoopRemoteConfigService();
  });

  group('NoopRemoteConfigService', () {
    test('initialize completes without throwing', () async {
      await expectLater(service.initialize(), completes);
    });

    test('getInt returns the expected default from RemoteConfigDefaults', () {
      expect(
        service.getInt('max_active_pacts'),
        RemoteConfigDefaults.maxActivePacts,
      );
    });

    test('getInt does not throw', () {
      expect(() => service.getInt('max_active_pacts'), returnsNormally);
    });

    test('getInt returns 0 for unknown key', () {
      expect(service.getInt('unknown_key'), 0);
    });

    test('getBool returns false for unknown key without throwing', () {
      expect(() => service.getBool('unknown_key'), returnsNormally);
      expect(service.getBool('unknown_key'), isFalse);
    });

    test('getString returns empty string for unknown key without throwing', () {
      expect(() => service.getString('unknown_key'), returnsNormally);
      expect(service.getString('unknown_key'), '');
    });

    test('getDouble returns 0.0 for unknown key without throwing', () {
      expect(() => service.getDouble('unknown_key'), returnsNormally);
      expect(service.getDouble('unknown_key'), 0.0);
    });
  });
}

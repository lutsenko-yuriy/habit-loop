import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_override_store.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_override_store.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/overridable_remote_config_service.dart';

// ---------------------------------------------------------------------------
// In-test fake store
// ---------------------------------------------------------------------------

class _FakeRemoteConfigOverrideStore implements RemoteConfigOverrideStore {
  final Map<String, String> _overrides = {};

  @override
  String? getOverride(String key) => _overrides[key];

  @override
  Future<void> setOverride(String key, String value) async {
    _overrides[key] = value;
  }

  @override
  Future<void> clearOverride(String key) async {
    _overrides.remove(key);
  }

  @override
  Map<String, String> getAllOverrides() => Map.unmodifiable(_overrides);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late NoopRemoteConfigService inner;
  late _FakeRemoteConfigOverrideStore store;
  late OverridableRemoteConfigService service;

  setUp(() {
    inner = NoopRemoteConfigService();
    store = _FakeRemoteConfigOverrideStore();
    service = OverridableRemoteConfigService(inner: inner, store: store);
  });

  group('OverridableRemoteConfigService.initialize', () {
    test('delegates to the inner service and completes', () async {
      await expectLater(service.initialize(), completes);
    });
  });

  group('OverridableRemoteConfigService.getInt', () {
    test('returns inner value when no override is set', () {
      expect(service.getInt('max_active_pacts'), RemoteConfigDefaults.maxActivePacts);
    });

    test('returns the parsed override value when set', () async {
      await store.setOverride('max_active_pacts', '10');

      expect(service.getInt('max_active_pacts'), 10);
    });

    test('falls back to inner when override is not a valid int', () async {
      await store.setOverride('max_active_pacts', 'not_a_number');

      expect(service.getInt('max_active_pacts'), RemoteConfigDefaults.maxActivePacts);
    });

    test('returns 0 for an unknown key with no override', () {
      expect(service.getInt('unknown_key'), 0);
    });
  });

  group('OverridableRemoteConfigService.getBool', () {
    test('returns inner value when no override is set', () {
      // NoopRemoteConfigService returns false for unknown bool keys.
      expect(service.getBool('some_bool_flag'), false);
    });

    test("returns true when override is 'true'", () async {
      await store.setOverride('some_bool_flag', 'true');

      expect(service.getBool('some_bool_flag'), isTrue);
    });

    test("returns false when override is 'false'", () async {
      await store.setOverride('some_bool_flag', 'false');

      expect(service.getBool('some_bool_flag'), isFalse);
    });

    test('falls back to inner when override is not a valid bool string', () async {
      await store.setOverride('some_bool_flag', 'yes');

      // Falls back to inner (noop returns false for unknown key).
      expect(service.getBool('some_bool_flag'), false);
    });
  });

  group('OverridableRemoteConfigService.getString', () {
    test('returns inner value when no override is set', () {
      expect(service.getString('notification_text_variant'), RemoteConfigDefaults.notificationTextVariant);
    });

    test('returns the override string directly when set', () async {
      await store.setOverride('notification_text_variant', 'deadline');

      expect(service.getString('notification_text_variant'), 'deadline');
    });

    test('returns empty string for unknown key with no override', () {
      expect(service.getString('unknown_key'), '');
    });
  });

  group('OverridableRemoteConfigService.getDouble', () {
    test('returns inner value when no override is set', () {
      expect(service.getDouble('unknown_double_key'), 0.0);
    });

    test('returns the parsed override value when set', () async {
      await store.setOverride('some_double_key', '3.14');

      expect(service.getDouble('some_double_key'), 3.14);
    });

    test('falls back to inner when override is not a valid double', () async {
      await store.setOverride('some_double_key', 'not_a_double');

      expect(service.getDouble('some_double_key'), 0.0);
    });
  });

  group('OverridableRemoteConfigService with NoopRemoteConfigOverrideStore', () {
    test('behaves identically to the inner service when store is noop', () {
      final noopService = OverridableRemoteConfigService(
        inner: NoopRemoteConfigService(),
        store: const NoopRemoteConfigOverrideStore(),
      );

      expect(noopService.getInt('max_active_pacts'), RemoteConfigDefaults.maxActivePacts);
      expect(noopService.getString('notification_text_variant'), RemoteConfigDefaults.notificationTextVariant);
      expect(noopService.getBool('unknown_key'), isFalse);
      expect(noopService.getDouble('unknown_key'), 0.0);
    });
  });
}

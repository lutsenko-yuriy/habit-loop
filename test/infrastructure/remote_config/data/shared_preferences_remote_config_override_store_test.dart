import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/data/shared_preferences_remote_config_override_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesRemoteConfigOverrideStore', () {
    test('getOverride returns null when key is not set', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      expect(store.getOverride('max_active_pacts'), isNull);
    });

    test('setOverride persists value; getOverride returns it', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      await store.setOverride('max_active_pacts', '5');

      expect(store.getOverride('max_active_pacts'), '5');
    });

    test('clearOverride removes the value; getOverride returns null again', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      await store.setOverride('max_active_pacts', '5');
      await store.clearOverride('max_active_pacts');

      expect(store.getOverride('max_active_pacts'), isNull);
    });

    test('getAllOverrides returns all set overrides', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      await store.setOverride('max_active_pacts', '5');
      await store.setOverride('notification_text_variant', 'deadline');

      expect(store.getAllOverrides(), {
        'max_active_pacts': '5',
        'notification_text_variant': 'deadline',
      });
    });

    test('getAllOverrides ignores unrelated prefs keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('unrelated_key', 'value');
      await prefs.setString('habit_loop_device_id', 'some-uuid');
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      await store.setOverride('max_active_pacts', '5');

      expect(store.getAllOverrides(), {'max_active_pacts': '5'});
    });

    test('multiple overrides can coexist', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      await store.setOverride('key_a', 'value_a');
      await store.setOverride('key_b', 'value_b');
      await store.setOverride('key_c', 'value_c');

      expect(store.getOverride('key_a'), 'value_a');
      expect(store.getOverride('key_b'), 'value_b');
      expect(store.getOverride('key_c'), 'value_c');
    });

    test('uses rc_override_ prefix in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      await store.setOverride('max_active_pacts', '7');

      expect(
        prefs.getString('${SharedPreferencesRemoteConfigOverrideStore.overridePrefix}max_active_pacts'),
        '7',
      );
    });

    test('persists overrides across store instances sharing the same prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await SharedPreferencesRemoteConfigOverrideStore(prefs).setOverride('max_active_pacts', '9');

      final store2 = SharedPreferencesRemoteConfigOverrideStore(prefs);
      expect(store2.getOverride('max_active_pacts'), '9');
    });

    test('setOverride never throws', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      await expectLater(store.setOverride('any_key', 'any_value'), completes);
    });

    test('clearOverride on non-existent key completes without throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      await expectLater(store.clearOverride('non_existent_key'), completes);
    });

    test('getAllOverrides returns empty map when no overrides are set', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);

      expect(store.getAllOverrides(), isEmpty);
    });
  });
}

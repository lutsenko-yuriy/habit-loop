import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/slices/debug/ui/generic/remote_config_overrides_view_model.dart';

import '../../../../infrastructure/remote_config/fake_remote_config_override_store.dart';
import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';

void main() {
  group('RemoteConfigOverridesViewModel', () {
    late FakeRemoteConfigOverrideStore store;
    late FakeRemoteConfigService service;
    late ProviderContainer container;

    setUp(() {
      store = FakeRemoteConfigOverrideStore();
      service = FakeRemoteConfigService();
      container = ProviderContainer(overrides: [
        remoteConfigOverrideStoreProvider.overrideWithValue(store),
        remoteConfigServiceProvider.overrideWithValue(service),
      ]);
    });

    tearDown(() => container.dispose());

    // Helper: subscribe so the AutoDispose provider stays alive.
    List<RemoteConfigEntry> readEntries() {
      container.listen(remoteConfigOverridesViewModelProvider, (_, __) {});
      return container.read(remoteConfigOverridesViewModelProvider);
    }

    test('exposes all keys from RemoteConfigDefaults.all', () {
      final entries = readEntries();
      expect(entries.map((e) => e.key).toSet(), equals(RemoteConfigDefaults.all.keys.toSet()));
    });

    test('every key appears exactly once', () {
      final entries = readEntries();
      expect(entries.length, equals(RemoteConfigDefaults.all.length));
    });

    test('all entries are non-overridden when store is empty', () {
      final entries = readEntries();
      expect(entries.every((e) => !e.isOverridden), isTrue);
    });

    test('defaultValue matches RemoteConfigDefaults.all string representation', () {
      final entries = readEntries();
      for (final e in entries) {
        expect(e.defaultValue, RemoteConfigDefaults.all[e.key].toString());
      }
    });

    test('allowedValues matches RemoteConfigDefaults.allowedValues for each key', () {
      final entries = readEntries();
      for (final e in entries) {
        expect(e.allowedValues, RemoteConfigDefaults.allowedValues[e.key]);
      }
    });

    test('hasAllowedValues is true for constrained keys and false for free-text keys', () {
      final entries = readEntries();
      final constrained = entries.where((e) => e.hasAllowedValues).map((e) => e.key).toSet();
      final free = entries.where((e) => !e.hasAllowedValues).map((e) => e.key).toSet();
      expect(
          constrained,
          containsAll([
            'notification_text_variant',
            'post_deadline_notification_behavior',
            'exp_003_commitment_confirmation',
            'debug_auth_state',
          ]));
      expect(free, containsAll(['max_active_pacts', 'onboarding_auto_advance_seconds']));
    });

    test('intRange matches RemoteConfigDefaults.intRanges for each key', () {
      final entries = readEntries();
      for (final e in entries) {
        expect(e.intRange, RemoteConfigDefaults.intRanges[e.key]);
      }
    });

    test('hasIntRange is true for bounded numeric keys', () {
      final entries = readEntries();
      final ranged = entries.where((e) => e.hasIntRange).map((e) => e.key).toSet();
      expect(
          ranged,
          containsAll([
            'debug_connectivity_stability_percent',
            'sync_max_consecutive_failures',
            'onboarding_auto_advance_seconds',
          ]));
    });

    test('hasIntRange is false for free-text and enum keys', () {
      final entries = readEntries();
      final noRange = entries.where((e) => !e.hasIntRange).map((e) => e.key).toSet();
      expect(
          noRange, containsAll(['max_active_pacts', 'debug_firestore_backend', 'debug_connectivity_state', 'debug_auth_state']));
    });

    test('debug_firestore_backend has allowedValues ["firebase", "fake"]', () {
      final entries = readEntries();
      final entry = entries.firstWhere((e) => e.key == 'debug_firestore_backend');
      expect(entry.allowedValues, ['firebase', 'fake']);
      expect(entry.hasAllowedValues, isTrue);
      expect(entry.hasIntRange, isFalse);
    });

    test('debug_auth_state has allowedValues ["real", "force_signed_in"]', () {
      final entries = readEntries();
      final entry = entries.firstWhere((e) => e.key == 'debug_auth_state');
      expect(entry.allowedValues, ['real', 'force_signed_in']);
      expect(entry.hasAllowedValues, isTrue);
      expect(entry.hasIntRange, isFalse);
      expect(entry.hasValueHint, isTrue);
    });

    test('effectiveValue reflects service getInt for int key', () {
      service.overrides['max_active_pacts'] = 7;
      final entries = readEntries();
      final entry = entries.firstWhere((e) => e.key == 'max_active_pacts');
      expect(entry.effectiveValue, '7');
    });

    test('effectiveValue reflects service getString for string key', () {
      service.overrides['notification_text_variant'] = 'deadline';
      final entries = readEntries();
      final entry = entries.firstWhere((e) => e.key == 'notification_text_variant');
      expect(entry.effectiveValue, 'deadline');
    });

    test('initial state reflects pre-existing overrides from store', () async {
      await store.setOverride('max_active_pacts', '5');
      final entries = readEntries();
      final entry = entries.firstWhere((e) => e.key == 'max_active_pacts');
      expect(entry.isOverridden, isTrue);
      expect(entry.overrideValue, '5');
    });

    test('setOverride marks entry overridden and updates overrideValue', () async {
      container.listen(remoteConfigOverridesViewModelProvider, (_, __) {});
      final notifier = container.read(remoteConfigOverridesViewModelProvider.notifier);

      await notifier.setOverride('max_active_pacts', '10');

      final entries = container.read(remoteConfigOverridesViewModelProvider);
      final entry = entries.firstWhere((e) => e.key == 'max_active_pacts');
      expect(entry.isOverridden, isTrue);
      expect(entry.overrideValue, '10');
    });

    test('setOverride persists to the store', () async {
      container.listen(remoteConfigOverridesViewModelProvider, (_, __) {});
      final notifier = container.read(remoteConfigOverridesViewModelProvider.notifier);

      await notifier.setOverride('max_active_pacts', '10');

      expect(store.getOverride('max_active_pacts'), '10');
    });

    test('clearOverride marks entry non-overridden', () async {
      await store.setOverride('max_active_pacts', '10');
      container.listen(remoteConfigOverridesViewModelProvider, (_, __) {});
      final notifier = container.read(remoteConfigOverridesViewModelProvider.notifier);

      await notifier.clearOverride('max_active_pacts');

      final entries = container.read(remoteConfigOverridesViewModelProvider);
      final entry = entries.firstWhere((e) => e.key == 'max_active_pacts');
      expect(entry.isOverridden, isFalse);
      expect(entry.overrideValue, isNull);
    });

    test('clearAllOverrides removes every override', () async {
      await store.setOverride('max_active_pacts', '10');
      await store.setOverride('notification_text_variant', 'deadline');
      container.listen(remoteConfigOverridesViewModelProvider, (_, __) {});
      final notifier = container.read(remoteConfigOverridesViewModelProvider.notifier);

      await notifier.clearAllOverrides();

      final entries = container.read(remoteConfigOverridesViewModelProvider);
      expect(entries.every((e) => !e.isOverridden), isTrue);
    });

    test('clearAllOverrides only clears keys in RemoteConfigDefaults.all', () async {
      // A stale key in the store that is NOT in RemoteConfigDefaults.all
      // should not cause errors — clearAllOverrides only touches known keys.
      await store.setOverride('unknown_key', 'value');
      container.listen(remoteConfigOverridesViewModelProvider, (_, __) {});
      final notifier = container.read(remoteConfigOverridesViewModelProvider.notifier);

      // Should not throw.
      await notifier.clearAllOverrides();

      // The unknown key is still in the store (we don't touch it).
      expect(store.getOverride('unknown_key'), 'value');
    });
  });
}

import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_override_store.dart';

/// An in-memory [RemoteConfigOverrideStore] for tests.
///
/// Backed by a plain [Map] — no SharedPreferences required.
final class FakeRemoteConfigOverrideStore implements RemoteConfigOverrideStore {
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

import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_override_store.dart';

/// A no-op [RemoteConfigOverrideStore] that never stores anything.
///
/// Used as the default for [remoteConfigOverrideStoreProvider] so tests and
/// release builds are unaffected by the debug override layer.
final class NoopRemoteConfigOverrideStore implements RemoteConfigOverrideStore {
  const NoopRemoteConfigOverrideStore();

  @override
  String? getOverride(String key) => null;

  @override
  Future<void> setOverride(String key, String value) async {}

  @override
  Future<void> clearOverride(String key) async {}

  @override
  Map<String, String> getAllOverrides() => const {};
}

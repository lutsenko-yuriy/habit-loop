/// Persistent store for debug-time Remote Config key overrides.
///
/// Overrides are stored as strings (type-erased) and interpreted at read time
/// by [OverridableRemoteConfigService]. Reads are synchronous — backed by an
/// in-memory representation (e.g. [SharedPreferences], which caches its values
/// in memory after the first load). Writes are async to allow persistence.
///
/// **Debug and profile builds only.** Do not wire this service in release
/// builds. [NoopRemoteConfigOverrideStore] is the safe default.
abstract interface class RemoteConfigOverrideStore {
  /// Returns the string-encoded override for [key], or `null` if none is set.
  String? getOverride(String key);

  /// Persists a string-encoded override for [key].
  ///
  /// The caller is responsible for encoding the value as a string that matches
  /// the expected type (e.g. `'5'` for an int, `'true'` for a bool).
  Future<void> setOverride(String key, String value);

  /// Removes the override for [key]. If no override exists, this is a no-op.
  Future<void> clearOverride(String key);

  /// Returns a snapshot of all current overrides keyed by Remote Config key.
  Map<String, String> getAllOverrides();
}

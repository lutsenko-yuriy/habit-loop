/// Abstract interface for the Remote Config service.
///
/// Inject via Riverpod (`remoteConfigServiceProvider`) so call sites are
/// decoupled from the Firebase SDK. Tests can override with a fake.
///
/// **No-throw contract:** all implementations must swallow exceptions
/// internally. Call sites may call any method without wrapping in try/catch.
abstract interface class RemoteConfigService {
  /// Fetches and activates Remote Config values.
  ///
  /// Should be called once at app startup. Swallows any network or SDK
  /// errors so a failed fetch never prevents the app from launching.
  ///
  /// The returned future resolves once in-code defaults are registered —
  /// it does NOT wait for the network fetch, so values read immediately
  /// after `await initialize()` may still be defaults. [onFetchComplete],
  /// if given, fires once the fetch actually settles (success or failure)
  /// so a caller can re-read values that must reflect the fetched state —
  /// e.g. mirroring a flag into a native platform channel (HAB-269 WU2
  /// audit finding: syncing only right after `initialize()` reads a
  /// stale/default value, not what was just fetched).
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> initialize({void Function()? onFetchComplete});

  /// Returns an int config value for [key].
  ///
  /// Falls back to the in-code default if the key is absent or on error.
  /// Never throws — implementations swallow failures silently.
  int getInt(String key);

  /// Returns a bool config value for [key].
  ///
  /// Falls back to the in-code default if the key is absent or on error.
  /// Never throws — implementations swallow failures silently.
  bool getBool(String key);

  /// Returns a string config value for [key].
  ///
  /// Falls back to the in-code default if the key is absent or on error.
  /// Never throws — implementations swallow failures silently.
  String getString(String key);

  /// Returns a double config value for [key].
  ///
  /// Falls back to the in-code default if the key is absent or on error.
  /// Never throws — implementations swallow failures silently.
  double getDouble(String key);
}

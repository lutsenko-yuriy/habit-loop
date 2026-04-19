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
  /// Never throws — implementations swallow failures silently.
  Future<void> initialize();

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

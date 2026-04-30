/// In-code default values for all Remote Config parameters.
///
/// This is the single source of truth for defaults. Both [FirebaseRemoteConfigService]
/// and [NoopRemoteConfigService] reference these values so the app behaves
/// identically when Remote Config is unreachable (offline / first launch).
///
/// Key naming convention: snake_case, matching the Firebase Remote Config
/// console and the analytics event parameter naming convention.
abstract final class RemoteConfigDefaults {
  /// Maximum number of active pacts a user may have simultaneously.
  ///
  /// Matches the current hardcoded threshold. Override in the Firebase Remote
  /// Config console to experiment with different limits without a release.
  static const int maxActivePacts = 3;

  /// All default values keyed by their Remote Config parameter name.
  ///
  /// Pass this map to `FirebaseRemoteConfig.setDefaults()` during initialisation
  /// so the SDK knows the fallback value for every parameter before the first
  /// successful fetch.
  static const Map<String, dynamic> all = {
    'max_active_pacts': maxActivePacts,
  };
}

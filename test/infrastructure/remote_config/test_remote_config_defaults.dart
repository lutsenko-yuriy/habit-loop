/// Shared Remote Config defaults for harness/test construction (HAB-260).
///
/// Entry criterion: a key belongs here when its *production* default would
/// intercept unrelated tests — e.g. a feature toggle that defaults `true` in
/// production but whose UI/copy differences would otherwise leak into tests
/// that have nothing to do with that feature. Most keys do not need an entry
/// here; only add one when a flag has actually caused this kind of collateral
/// breakage (see HAB-232 WU7/WU10 for the precedent).
abstract final class TestRemoteConfigDefaults {
  /// HAB-232: personalized display-name copy defaults on in production
  /// (`RemoteConfigDefaults.displayNamePersonalizationEnabled == true`), which
  /// would otherwise force every unrelated test to pin a display name or
  /// accept personalized copy it isn't asserting on. Test default: off.
  static const Map<String, dynamic> all = {
    'display_name_personalization_enabled': false,
  };
}

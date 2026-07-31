/// The running app's version name, kept in sync with `pubspec.yaml`'s
/// `version:` field.
///
/// Manually bumped in the same commit that bumps `pubspec.yaml` — mirrors
/// `docs/VERSIONING.md`'s existing "manual, reasoned" version-bump ritual.
/// Used by [RemoteConfigDefaults.releaseVersions]-gated feature flags
/// (`FeatureFlags.fromRemoteConfig`) to decide whether a toggle's release
/// version requirement is satisfied by the version actually running.
const String currentAppVersion = '0.53.0';

/// Whether [current] is at least [required], comparing both as `X.Y.Z`
/// version strings.
///
/// Missing trailing segments are treated as `0` (e.g. `"1.2"` == `"1.2.0"`).
/// Defensive: any non-numeric segment in either string makes the comparison
/// unparseable, and this returns `false` (not satisfied) rather than
/// throwing — the safe fallback for a release-gating check, where failing
/// closed (feature stays hidden) is preferable to failing open.
bool isAtLeast(String current, String required) {
  final currentParts = _parseVersion(current);
  final requiredParts = _parseVersion(required);
  if (currentParts == null || requiredParts == null) {
    return false;
  }

  final length = currentParts.length > requiredParts.length ? currentParts.length : requiredParts.length;
  for (var i = 0; i < length; i++) {
    final currentSegment = i < currentParts.length ? currentParts[i] : 0;
    final requiredSegment = i < requiredParts.length ? requiredParts[i] : 0;
    if (currentSegment != requiredSegment) {
      return currentSegment > requiredSegment;
    }
  }
  return true;
}

/// Parses an `X.Y.Z`-style version string into its integer segments.
///
/// Strips build metadata first (`+build`/`-prerelease`, e.g. the
/// `pubspec.yaml`-style `"0.53.0+174"`) so passing the full version string
/// by mistake degrades to comparing the `X.Y.Z` part instead of failing
/// closed on the non-numeric build number.
///
/// Returns `null` if the string is empty or any remaining segment fails to
/// parse as a non-negative integer.
List<int>? _parseVersion(String version) {
  if (version.isEmpty) {
    return null;
  }
  final withoutMetadata = version.split(RegExp(r'[+-]')).first;
  final segments = withoutMetadata.split('.');
  final parsed = <int>[];
  for (final segment in segments) {
    final value = int.tryParse(segment);
    if (value == null) {
      return null;
    }
    parsed.add(value);
  }
  return parsed;
}

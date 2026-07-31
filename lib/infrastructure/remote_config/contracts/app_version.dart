/// Sentinel version that satisfies every release gate — the default for
/// callers that don't care about gating (most tests). Opposite of
/// `main.dart`'s fail-closed `''` fallback.
const String unspecifiedAppVersion = '9999.0.0';

/// Whether [current] is at least [required] (`X.Y.Z` strings). Missing
/// segments count as `0`. Unparseable input fails closed (`false`) — safer
/// for a release gate than throwing.
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

/// Parses `X.Y.Z` into integer segments, stripping `+build`/`-prerelease`
/// first (e.g. `pubspec.yaml`'s `"0.53.0+174"`). Returns `null` if any
/// segment isn't a non-negative integer.
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

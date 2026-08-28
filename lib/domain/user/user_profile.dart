/// The user's optional display name (HAB-232).
///
/// `displayName` is nullable: `null` means "never entered, or deliberately
/// skipped" — a skip is not tracked as a separate flag, so there is exactly
/// one "no name" state. Empty and whitespace-only input normalises to `null`
/// here (constructor + [copyWith]) so that invariant actually holds — every
/// caller (UI, mapper, sync) can treat `displayName == null` as the sole "no
/// name" check without also handling `''`. The only user-scoped setting that
/// is synced; locale and the onboarding-passed flag remain local
/// SharedPreferences values.
class UserProfile {
  final String? displayName;
  final DateTime updatedAt;

  UserProfile({String? displayName, required this.updatedAt}) : displayName = _normalize(displayName);

  UserProfile copyWith({
    String? displayName,
    DateTime? updatedAt,
    bool clearDisplayName = false,
  }) {
    return UserProfile(
      // Normalization happens in the constructor below — passing the raw
      // value through here (not pre-normalized) preserves the "not passed
      // vs. explicitly passed an empty string" distinction: an explicit ''
      // must clear the name, not fall through to `this.displayName`, which
      // pre-normalizing here would have collapsed into (both become null).
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile && displayName == other.displayName && updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(displayName, updatedAt);
}

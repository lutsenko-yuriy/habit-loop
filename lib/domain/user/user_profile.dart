/// The user's optional display name (HAB-232).
///
/// `displayName` is nullable: `null` means "never entered, or deliberately
/// skipped" — a skip is not tracked as a separate flag, so there is exactly
/// one "no name" state. The only user-scoped setting that is synced; locale
/// and the onboarding-passed flag remain local SharedPreferences values.
class UserProfile {
  final String? displayName;
  final DateTime updatedAt;

  const UserProfile({this.displayName, required this.updatedAt});

  UserProfile copyWith({
    String? displayName,
    DateTime? updatedAt,
    bool clearDisplayName = false,
  }) {
    return UserProfile(
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile && displayName == other.displayName && updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(displayName, updatedAt);
}

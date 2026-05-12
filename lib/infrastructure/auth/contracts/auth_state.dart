class AuthState {
  const AuthState({required this.userId, required this.isAnonymous})
      : assert(
          userId != null || isAnonymous,
          'A non-anonymous state requires a non-null userId',
        );

  final String? userId;

  /// True when the user is signed in anonymously (no linked account).
  ///
  /// Valid combinations:
  ///   userId == null,  isAnonymous == true  — not signed in (initial / signed out)
  ///   userId != null,  isAnonymous == true  — signed in anonymously
  ///   userId != null,  isAnonymous == false — signed in with linked Google account
  ///
  /// The combination userId == null && !isAnonymous is a logic error and is
  /// guarded by the constructor assert.
  final bool isAnonymous;

  bool get isSignedIn => userId != null;

  @override
  bool operator ==(Object other) => other is AuthState && other.userId == userId && other.isAnonymous == isAnonymous;

  @override
  int get hashCode => Object.hash(userId, isAnonymous);
}

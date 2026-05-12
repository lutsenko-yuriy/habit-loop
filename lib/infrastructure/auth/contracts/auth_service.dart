import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';

/// Abstract interface for Firebase Auth operations.
///
/// Inject via Riverpod (`authServiceProvider`). Tests override with
/// [FakeAuthService].
///
/// **No-throw contract:** [initialize], [signOut] never throw.
/// [linkWithGoogle] may throw [FirebaseAuthException] on credential conflict —
/// callers must handle it.
abstract interface class AuthService {
  /// Signs in anonymously if no cached user exists.
  ///
  /// Safe to call on every app start. No-op when a user is already signed in.
  /// Never throws.
  Future<void> initialize();

  /// The Firebase UID of the current user, or `null` if not signed in.
  String? get currentUserId;

  /// Whether the current user is anonymous (not linked to a real account).
  bool get isAnonymous;

  /// Stream of [AuthState] that emits whenever the auth state changes.
  Stream<AuthState> get authStateChanges;

  /// Links the current anonymous account to a Google credential.
  ///
  /// On success the UID stays the same and [isAnonymous] becomes `false`.
  /// Throws [FirebaseAuthException] with code `credential-already-in-use` if
  /// the Google account is already linked to a different Firebase user.
  Future<void> linkWithGoogle();

  /// Signs out the current user. Never throws.
  Future<void> signOut();
}

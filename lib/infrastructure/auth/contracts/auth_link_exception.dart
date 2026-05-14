/// Thrown by [AuthService.linkWithGoogle] on credential conflict.
///
/// Wraps the Firebase-specific error code in a domain type so callers in the
/// UI layer never need to import `package:firebase_auth`.
final class AuthLinkException implements Exception {
  const AuthLinkException({required this.code});

  /// The Firebase Auth error code, e.g. `account-exists-with-different-credential`.
  final String code;

  @override
  String toString() => 'AuthLinkException(code: $code)';
}

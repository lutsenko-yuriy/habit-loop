class AuthState {
  const AuthState({required this.userId, required this.isAnonymous});

  final String? userId;
  final bool isAnonymous;

  bool get isSignedIn => userId != null;
}

import 'dart:async';

import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';

/// Debug/profile-only [AuthService] that simulates auth without Firebase.
///
/// Starts anonymous and immediately transitions to a signed-in state when
/// [linkWithGoogle] is called — no real OAuth flow is performed. This pairs
/// with [FakeFirestoreClient] when `debug_backend = local` to allow full
/// sync-flow testing with no network dependencies.
///
/// | Lifecycle | Behaviour |
/// |---|---|
/// | After [initialize] | anonymous — [currentUserId] is null, [isAnonymous] is true |
/// | After [linkWithGoogle] | signed-in — [currentUserId] returns [localUserId], [isAnonymous] is false |
/// | After [signOut] | anonymous again |
///
/// **Debug/profile only.** Never constructed in release builds.
class LocalAuthService implements AuthService {
  /// The fixed user ID emitted after [linkWithGoogle].
  static const String localUserId = 'local_user_id';

  final _controller = StreamController<AuthState>.broadcast();

  AuthState _state = const AuthState(userId: null, isAnonymous: true);

  @override
  Future<void> initialize() async {
    // Start anonymous — no Firebase call needed.
    _emit(_state);
  }

  @override
  String? get currentUserId => _state.userId;

  @override
  bool get isAnonymous => _state.isAnonymous;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  /// Immediately simulates a successful Google sign-in.
  ///
  /// Sets [isAnonymous] to false and [currentUserId] to [localUserId].
  /// No network call or OAuth flow is performed — the transition is
  /// synchronous from the caller's perspective.
  @override
  Future<void> linkWithGoogle() async {
    _emit(const AuthState(userId: localUserId, isAnonymous: false));
  }

  @override
  Future<void> signOut() async {
    _emit(const AuthState(userId: null, isAnonymous: true));
  }

  void _emit(AuthState newState) {
    _state = newState;
    _controller.add(newState);
  }

  /// Releases the underlying [StreamController].
  ///
  /// Call this when the app is shutting down or in tests to avoid stream leaks.
  void dispose() => _controller.close();
}

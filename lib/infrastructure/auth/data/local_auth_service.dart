import 'dart:async';

import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';

/// Debug/profile-only [AuthService] that simulates auth without Firebase.
///
/// Immediately signs in as [localUserId] on [initialize] — no real OAuth flow
/// is performed. This pairs with [FakeFirestoreClient] when
/// `debug_backend = local` to allow full sync-flow testing with no network
/// dependencies. The user is pre-signed-in on every app restart so the
/// dashboard is accessible immediately without a manual "Sign in with Google"
/// tap after switching to the local backend.
///
/// | Lifecycle | Behaviour |
/// |---|---|
/// | After [initialize] | signed-in — [currentUserId] returns [localUserId], [isAnonymous] is false |
/// | After [signOut] | anonymous — [currentUserId] is null, [isAnonymous] is true |
/// | After [linkWithGoogle] | signed-in again — same as after [initialize] |
///
/// **Debug/profile only.** Never constructed in release builds.
class LocalAuthService implements AuthService {
  /// The fixed user ID emitted after [linkWithGoogle].
  static const String localUserId = 'local_user_id';

  final _controller = StreamController<AuthState>.broadcast();

  AuthState _state = const AuthState(userId: null, isAnonymous: true);

  /// Set to `true` after the first [initialize] call.
  ///
  /// [authStateChanges] uses this flag to replay the current state to
  /// subscribers that attach after [initialize] has already emitted to nobody
  /// (the typical production scenario: [initialize] is called fire-and-forget
  /// from `main()`, before the first frame's [authStateChangesProvider]
  /// subscription is established).
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    // Auto-sign-in as localUserId — no Firebase or OAuth call needed.
    // With debug_backend = local the user is always pre-signed-in on every
    // app restart so the dashboard is immediately accessible without a manual
    // "Sign in with Google" tap after the backend switch.
    _initialized = true;
    _emit(const AuthState(userId: localUserId, isAnonymous: false));
  }

  @override
  String? get currentUserId => _state.userId;

  @override
  bool get isAnonymous => _state.isAnonymous;

  /// A stream of [AuthState] changes.
  ///
  /// **Late-subscriber replay:** if [initialize] has already been called when a
  /// subscriber attaches, the subscriber synchronously receives the current
  /// state before any future changes are forwarded. This prevents
  /// [authStateChangesProvider] from staying [AsyncLoading] indefinitely when
  /// it subscribes on the first frame and `main()` has already called
  /// [initialize] fire-and-forget.
  ///
  /// If [initialize] has *not* yet been called, the raw controller stream is
  /// returned so listeners receive events exactly as they fire — preserving the
  /// behaviour expected by tests that subscribe before [initialize].
  @override
  Stream<AuthState> get authStateChanges {
    if (!_initialized) {
      return _controller.stream;
    }
    // initialize() has already run. Build a single-subscription stream that
    // synchronously delivers the current state to the new subscriber and then
    // forwards all future emissions from [_controller].
    final sc = StreamController<AuthState>(sync: true);
    late StreamSubscription<AuthState> inner;
    sc.onListen = () {
      sc.add(_state); // synchronous delivery — subscriber gets it before .listen() returns
      inner = _controller.stream.listen(
        sc.add,
        onError: sc.addError,
        onDone: sc.close,
      );
    };
    sc.onCancel = () => inner.cancel();
    return sc.stream;
  }

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

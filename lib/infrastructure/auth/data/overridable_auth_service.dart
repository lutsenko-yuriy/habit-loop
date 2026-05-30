import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';

/// Debug/profile-only [AuthService] decorator that can override the auth state
/// based on the `debug_auth_state` Remote Config key.
///
/// ## Auth modes (key `debug_auth_state`)
///
/// | Value | Behaviour |
/// |---|---|
/// | `'real'` (default) | Delegates to [inner] — real Firebase Auth. |
/// | `'force_signed_in'` | Returns a fake non-anonymous state immediately. |
///
/// When `force_signed_in` is active:
/// - [authStateChanges] emits `AuthState(userId: debugFakeUserId, isAnonymous: false)`.
/// - [currentUserId] returns [debugFakeUserId].
/// - [isAnonymous] returns `false`.
/// - [linkWithGoogle] is a silent no-op (user is already "signed in").
/// - [initialize] and [signOut] still delegate to [inner].
///
/// Switching via the in-app RC overrides screen takes effect immediately because
/// [RemoteConfigOverridesViewModel] invalidates [authStateChangesProvider] after
/// saving the override — this forces the [StreamProvider] to re-subscribe and
/// pick up the new mode.
///
/// **Debug/profile only** — never construct this class in release builds.
class OverridableAuthService implements AuthService {
  OverridableAuthService({
    required AuthService inner,
    required RemoteConfigService rc,
  })  : _inner = inner,
        _rc = rc;

  final AuthService _inner;
  final RemoteConfigService _rc;

  static const _keyAuthState = 'debug_auth_state';

  /// The fixed fake user ID used when `debug_auth_state = force_signed_in`.
  static const String debugFakeUserId = 'debug_fake_user_id';

  bool get _isForcedSignedIn => _rc.getString(_keyAuthState) == 'force_signed_in';

  @override
  Future<void> initialize() => _inner.initialize();

  @override
  String? get currentUserId => _isForcedSignedIn ? debugFakeUserId : _inner.currentUserId;

  @override
  bool get isAnonymous => _isForcedSignedIn ? false : _inner.isAnonymous;

  @override
  Stream<AuthState> get authStateChanges {
    if (_isForcedSignedIn) {
      return Stream.value(const AuthState(userId: debugFakeUserId, isAnonymous: false));
    }
    return _inner.authStateChanges;
  }

  /// No-op when `force_signed_in` is active (already "signed in" via override).
  /// Delegates to [inner] otherwise.
  @override
  Future<void> linkWithGoogle() {
    if (_isForcedSignedIn) return Future.value();
    return _inner.linkWithGoogle();
  }

  @override
  Future<void> signOut() => _inner.signOut();
}

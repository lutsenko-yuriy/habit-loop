import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';

/// Thin abstraction over the Firebase Auth SDK.
///
/// No Firebase SDK types leak through this interface, so test fakes can
/// implement it without importing `package:firebase_auth`.
abstract interface class FirebaseAuthClient {
  /// The raw current-user object, or null if not signed in.
  dynamic get currentUser;

  /// The UID of the current user, or null.
  String? get currentUserId;

  /// Whether the current user is anonymous.
  bool get isAnonymous;

  Future<void> signInAnonymously();

  Future<void> linkWithGoogleCredential();

  Future<void> signOut();

  Stream<AuthState> get authStateChanges;
}

/// [AuthService] implementation backed by Firebase Auth.
final class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._client);

  final FirebaseAuthClient _client;

  @override
  Future<void> initialize() async {
    if (_client.currentUser != null) return;
    try {
      await _client.signInAnonymously();
    } catch (_) {
      // Anonymous sign-in failures must never prevent the app from launching.
    }
  }

  @override
  String? get currentUserId => _client.currentUserId;

  @override
  bool get isAnonymous => _client.isAnonymous;

  @override
  Stream<AuthState> get authStateChanges => _client.authStateChanges;

  @override
  Future<void> linkWithGoogle() async {
    try {
      await _client.linkWithGoogleCredential();
    } on FirebaseAuthException catch (e) {
      throw AuthLinkException(code: e.code);
    } catch (e) {
      throw AuthLinkException(code: e.runtimeType.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (_) {
      // Sign-out failures must never crash the app.
    }
  }
}

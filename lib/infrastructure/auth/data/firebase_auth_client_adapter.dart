import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';
import 'package:habit_loop/infrastructure/auth/data/firebase_auth_service.dart';

/// Wraps [FirebaseAuth] and [GoogleSignIn] for use by [FirebaseAuthService].
///
/// Only instantiated in `main.dart`. No Firebase or Google SDK types leak
/// through [FirebaseAuthClient].
///
/// [GoogleSignIn] is initialized lazily on the first [linkWithGoogleCredential]
/// call so app startup is not blocked by the SDK init.
final class FirebaseAuthClientAdapter implements FirebaseAuthClient {
  FirebaseAuthClientAdapter(this._auth);

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  @override
  dynamic get currentUser => _auth.currentUser;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  @override
  Future<void> signInAnonymously() => _auth.signInAnonymously();

  @override
  Future<void> linkWithGoogleCredential() async {
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.currentUser!.linkWithCredential(credential);
  }

  @override
  Future<void> signOut() async {
    if (_googleInitialized) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  @override
  Stream<AuthState> get authStateChanges => _auth.authStateChanges().map(
        (user) => AuthState(
          userId: user?.uid,
          isAnonymous: user?.isAnonymous ?? true,
        ),
      );
}

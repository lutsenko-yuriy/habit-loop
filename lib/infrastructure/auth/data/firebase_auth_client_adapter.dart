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
    await GoogleSignIn.instance.initialize(
      // Web OAuth client ID — required on Android to include an idToken in the
      // authentication response. iOS reads CLIENT_ID from GoogleService-Info.plist
      // automatically but also benefits from having serverClientId set.
      serverClientId: '935013168355-ogdf1gpqbngv3kdmft7g0rn0pk498dpt.apps.googleusercontent.com',
    );
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
    if (idToken == null) throw Exception('Google Sign-In returned a null idToken');
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    try {
      await _auth.currentUser!.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // This Google account is linked to a different Firebase UID (e.g. from
        // a previous install). Sign in directly to restore that account.
        await _auth.signInWithCredential(credential);
      } else if (e.code == 'provider-already-linked') {
        // Already linked — nothing to do.
        return;
      } else {
        rethrow;
      }
    }
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

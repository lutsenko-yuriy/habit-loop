import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';
import 'package:habit_loop/infrastructure/auth/data/firebase_auth_service.dart';

// ---------------------------------------------------------------------------
// Fake client helpers
// ---------------------------------------------------------------------------

class _FakeUser {
  _FakeUser({required this.uid, required this.isAnonymous});
  final String uid;
  final bool isAnonymous;
}

class _FakeFirebaseAuthClient implements FirebaseAuthClient {
  _FakeFirebaseAuthClient({_FakeUser? initialUser}) : _currentUser = initialUser;

  _FakeUser? _currentUser;
  bool signInAnonymouslyCalled = false;
  bool linkWithGoogleCalled = false;
  bool signOutCalled = false;
  Exception? linkError;

  final _controller = StreamController<_FakeUser?>.broadcast();

  @override
  dynamic get currentUser => _currentUser;

  @override
  String? get currentUserId => _currentUser?.uid;

  @override
  bool get isAnonymous => _currentUser?.isAnonymous ?? true;

  @override
  Future<void> signInAnonymously() async {
    signInAnonymouslyCalled = true;
    _currentUser = _FakeUser(uid: 'anon-uid', isAnonymous: true);
    _controller.add(_currentUser);
  }

  @override
  Future<void> linkWithGoogleCredential() async {
    linkWithGoogleCalled = true;
    if (linkError != null) throw linkError!;
    _currentUser = _FakeUser(uid: 'anon-uid', isAnonymous: false);
    _controller.add(_currentUser);
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Stream<AuthState> get authStateChanges => _controller.stream.map(
        (user) => AuthState(
          userId: user?.uid,
          isAnonymous: user?.isAnonymous ?? true,
        ),
      );

  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FirebaseAuthService', () {
    late _FakeFirebaseAuthClient client;
    late FirebaseAuthService service;

    setUp(() {
      client = _FakeFirebaseAuthClient();
      service = FirebaseAuthService(client);
    });

    tearDown(() => client.dispose());

    test('initialize calls signInAnonymously when no current user', () async {
      await service.initialize();
      expect(client.signInAnonymouslyCalled, isTrue);
    });

    test('initialize skips signInAnonymously when user already cached', () async {
      client = _FakeFirebaseAuthClient(
        initialUser: _FakeUser(uid: 'existing-uid', isAnonymous: true),
      );
      service = FirebaseAuthService(client);

      await service.initialize();

      expect(client.signInAnonymouslyCalled, isFalse);
    });

    test('currentUserId reflects the client user ID', () async {
      await service.initialize();
      expect(service.currentUserId, equals('anon-uid'));
    });

    test('isAnonymous is true for an anonymous user', () async {
      await service.initialize();
      expect(service.isAnonymous, isTrue);
    });

    test('isAnonymous is false after linking', () async {
      client = _FakeFirebaseAuthClient(
        initialUser: _FakeUser(uid: 'anon-uid', isAnonymous: true),
      );
      service = FirebaseAuthService(client);
      await service.linkWithGoogle();
      expect(service.isAnonymous, isFalse);
    });

    test('linkWithGoogle delegates to client', () async {
      await service.initialize();
      await service.linkWithGoogle();
      expect(client.linkWithGoogleCalled, isTrue);
    });

    test('linkWithGoogle wraps plain Exception as AuthLinkException', () async {
      client.linkError = Exception('credential-already-in-use');
      await service.initialize();
      await expectLater(service.linkWithGoogle(), throwsA(isA<AuthLinkException>()));
    });

    test('linkWithGoogle wraps FirebaseAuthException as AuthLinkException with correct code', () async {
      client.linkError = FirebaseAuthException(code: 'account-exists-with-different-credential');
      await service.initialize();
      await expectLater(
        service.linkWithGoogle(),
        throwsA(
          isA<AuthLinkException>().having(
            (e) => e.code,
            'code',
            'account-exists-with-different-credential',
          ),
        ),
      );
    });

    test('signOut delegates to client', () async {
      await service.initialize();
      await service.signOut();
      expect(client.signOutCalled, isTrue);
    });

    test('authStateChanges emits when auth state updates', () async {
      final states = <AuthState>[];
      final sub = service.authStateChanges.listen(states.add);
      await service.initialize();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(states, isNotEmpty);
    });

    test('linkWithGoogle succeeds after signOut (no current user)', () async {
      await service.initialize();
      await service.signOut();
      // After sign-out currentUser is null; linkWithGoogle must not throw.
      await service.linkWithGoogle();
      expect(client.linkWithGoogleCalled, isTrue);
      expect(service.isAnonymous, isFalse);
    });
  });
}

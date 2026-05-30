import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';
import 'package:habit_loop/infrastructure/auth/data/local_auth_service.dart';

void main() {
  group('LocalAuthService', () {
    late LocalAuthService sut;

    setUp(() {
      sut = LocalAuthService();
    });

    tearDown(() => sut.dispose());

    // ── initial state (before initialize) ────────────────────────────────────

    test('currentUserId is null before initialize', () {
      expect(sut.currentUserId, isNull);
    });

    test('isAnonymous is true before initialize', () {
      expect(sut.isAnonymous, isTrue);
    });

    // ── after initialize ──────────────────────────────────────────────────────

    test('initialize completes without throwing', () async {
      await expectLater(sut.initialize(), completes);
    });

    test('initialize does not change anonymous state', () async {
      await sut.initialize();
      expect(sut.isAnonymous, isTrue);
      expect(sut.currentUserId, isNull);
    });

    test('authStateChanges emits anonymous state after initialize', () async {
      final states = <AuthState>[];
      final sub = sut.authStateChanges.listen(states.add);
      await sut.initialize();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(states.length, 1);
      expect(states.first.isAnonymous, isTrue);
      expect(states.first.userId, isNull);
    });

    test('authStateChanges emits current state to subscriber that attaches after initialize', () async {
      // initialize() runs first — as in production where main() calls it
      // fire-and-forget before authStateChangesProvider subscribes.
      await sut.initialize();

      final states = <AuthState>[];
      final sub = sut.authStateChanges.listen(states.add);
      // Allow microtasks to flush the initial-state yield.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // Subscriber should receive exactly one event: the current anonymous state.
      expect(states.length, 1);
      expect(states.first.isAnonymous, isTrue);
      expect(states.first.userId, isNull);
    });

    // ── linkWithGoogle ────────────────────────────────────────────────────────

    test('linkWithGoogle sets isAnonymous to false', () async {
      await sut.linkWithGoogle();
      expect(sut.isAnonymous, isFalse);
    });

    test('linkWithGoogle sets currentUserId to localUserId', () async {
      await sut.linkWithGoogle();
      expect(sut.currentUserId, LocalAuthService.localUserId);
    });

    test('linkWithGoogle emits signed-in AuthState', () async {
      final states = <AuthState>[];
      final sub = sut.authStateChanges.listen(states.add);
      await sut.linkWithGoogle();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(states.length, 1);
      expect(states.first.userId, LocalAuthService.localUserId);
      expect(states.first.isAnonymous, isFalse);
      expect(states.first.isSignedIn, isTrue);
    });

    // ── signOut ───────────────────────────────────────────────────────────────

    test('signOut reverts to anonymous state', () async {
      await sut.linkWithGoogle();
      await sut.signOut();
      expect(sut.isAnonymous, isTrue);
      expect(sut.currentUserId, isNull);
    });

    test('signOut emits anonymous AuthState', () async {
      final states = <AuthState>[];
      final sub = sut.authStateChanges.listen(states.add);
      await sut.linkWithGoogle();
      await sut.signOut();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(states.length, 2);
      expect(states[0].isAnonymous, isFalse); // after linkWithGoogle
      expect(states[1].isAnonymous, isTrue); // after signOut
      expect(states[1].userId, isNull);
    });

    // ── full sign-in → sign-out cycle ─────────────────────────────────────────

    test('full cycle: initialize → linkWithGoogle → signOut', () async {
      await sut.initialize();
      expect(sut.isAnonymous, isTrue);

      await sut.linkWithGoogle();
      expect(sut.isAnonymous, isFalse);
      expect(sut.currentUserId, LocalAuthService.localUserId);

      await sut.signOut();
      expect(sut.isAnonymous, isTrue);
      expect(sut.currentUserId, isNull);
    });

    // ── localUserId constant ──────────────────────────────────────────────────

    test('localUserId constant is non-empty', () {
      expect(LocalAuthService.localUserId, isNotEmpty);
    });
  });
}

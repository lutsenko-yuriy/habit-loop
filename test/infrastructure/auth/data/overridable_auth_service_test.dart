import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/data/overridable_auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';

import '../fake_auth_service.dart';
import '../../remote_config/fake_remote_config_service.dart';

void main() {
  group('OverridableAuthService', () {
    late FakeAuthService inner;
    late FakeRemoteConfigService rc;
    late OverridableAuthService sut;

    setUp(() {
      inner = FakeAuthService(userId: 'firebase_uid', isAnonymous: true);
      rc = FakeRemoteConfigService();
      sut = OverridableAuthService(inner: inner, rc: rc);
    });

    tearDown(() => inner.dispose());

    // ── real mode (default) ──────────────────────────────────────────────────

    group('when debug_auth_state = real (default)', () {
      test('isAnonymous delegates to inner', () {
        expect(sut.isAnonymous, isTrue);
      });

      test('currentUserId delegates to inner', () {
        expect(sut.currentUserId, 'firebase_uid');
      });

      test('authStateChanges emits inner stream events', () async {
        final states = <AuthState>[];
        final sub = sut.authStateChanges.listen(states.add);
        inner.emitState(userId: 'firebase_uid', isAnonymous: false);
        await Future<void>.delayed(Duration.zero);
        sub.cancel();
        expect(states, [const AuthState(userId: 'firebase_uid', isAnonymous: false)]);
      });

      test('linkWithGoogle delegates to inner', () async {
        await sut.linkWithGoogle();
        // inner.linkWithGoogle sets isAnonymous false
        expect(inner.isAnonymous, isFalse);
      });

      test('initialize delegates to inner (no-throw)', () async {
        await expectLater(sut.initialize(), completes);
      });

      test('signOut delegates to inner', () async {
        await sut.signOut();
        expect(inner.currentUserId, isNull);
      });
    });

    // ── force_signed_in mode ─────────────────────────────────────────────────

    group('when debug_auth_state = force_signed_in', () {
      setUp(() => rc.overrides['debug_auth_state'] = 'force_signed_in');

      test('isAnonymous returns false', () {
        expect(sut.isAnonymous, isFalse);
      });

      test('currentUserId returns fake ID', () {
        expect(sut.currentUserId, OverridableAuthService.debugFakeUserId);
      });

      test('authStateChanges emits fake signed-in AuthState', () async {
        final states = await sut.authStateChanges.toList();
        expect(states.length, 1);
        expect(states.first.userId, OverridableAuthService.debugFakeUserId);
        expect(states.first.isAnonymous, isFalse);
        expect(states.first.isSignedIn, isTrue);
      });

      test('linkWithGoogle is a silent no-op', () async {
        // Inner should NOT be mutated.
        await sut.linkWithGoogle();
        expect(inner.isAnonymous, isTrue); // unchanged
      });

      test('initialize still delegates to inner', () async {
        await expectLater(sut.initialize(), completes);
      });

      test('signOut still delegates to inner', () async {
        await sut.signOut();
        expect(inner.currentUserId, isNull);
      });
    });

    // ── runtime switch ───────────────────────────────────────────────────────

    test('switches from real to forced on next read after override changes', () {
      // Initially real.
      expect(sut.isAnonymous, isTrue);
      expect(sut.currentUserId, 'firebase_uid');

      // Set override at runtime.
      rc.overrides['debug_auth_state'] = 'force_signed_in';

      // Next read reflects override immediately.
      expect(sut.isAnonymous, isFalse);
      expect(sut.currentUserId, OverridableAuthService.debugFakeUserId);
    });

    test('switches back to real when override is cleared', () {
      rc.overrides['debug_auth_state'] = 'force_signed_in';
      expect(sut.isAnonymous, isFalse);

      rc.overrides.remove('debug_auth_state');
      expect(sut.isAnonymous, isTrue);
      expect(sut.currentUserId, 'firebase_uid');
    });
  });
}

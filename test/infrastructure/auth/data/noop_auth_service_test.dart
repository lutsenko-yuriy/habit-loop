import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/data/noop_auth_service.dart';

void main() {
  group('NoopAuthService', () {
    late NoopAuthService service;

    setUp(() => service = NoopAuthService());

    test('currentUserId is null', () {
      expect(service.currentUserId, isNull);
    });

    test('isAnonymous is true', () {
      expect(service.isAnonymous, isTrue);
    });

    test('initialize never throws', () async {
      await expectLater(service.initialize(), completes);
    });

    test('linkWithGoogle never throws', () async {
      await expectLater(service.linkWithGoogle(), completes);
    });

    test('signOut never throws', () async {
      await expectLater(service.signOut(), completes);
    });

    test('authStateChanges emits one AuthState and closes', () async {
      final states = await service.authStateChanges.toList();
      expect(states, hasLength(1));
      expect(states.first.userId, isNull);
      expect(states.first.isAnonymous, isTrue);
    });
  });
}

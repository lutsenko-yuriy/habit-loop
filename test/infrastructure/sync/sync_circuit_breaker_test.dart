import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';

void main() {
  group('SyncCircuitBreaker', () {
    late SyncCircuitBreaker cb;

    setUp(() {
      cb = SyncCircuitBreaker();
    });

    tearDown(() {
      cb.dispose();
    });

    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('starts in closed state', () {
      expect(cb.state, SyncCbState.closed);
    });

    test('canRequest is true when closed', () {
      expect(cb.canRequest, isTrue);
    });

    // -------------------------------------------------------------------------
    // Closed → Half-open on first failure
    // -------------------------------------------------------------------------

    test('recordFailure when closed transitions to halfOpen', () {
      cb.recordFailure();

      expect(cb.state, SyncCbState.halfOpen);
    });

    test('canRequest is true when halfOpen', () {
      cb.recordFailure();

      expect(cb.canRequest, isTrue);
    });

    // -------------------------------------------------------------------------
    // Half-open → Closed on success
    // -------------------------------------------------------------------------

    test('recordSuccess when halfOpen transitions to closed', () {
      cb.recordFailure(); // → halfOpen
      cb.recordSuccess();

      expect(cb.state, SyncCbState.closed);
    });

    test('recordSuccess when closed is a no-op', () {
      cb.recordSuccess();

      expect(cb.state, SyncCbState.closed);
    });

    // -------------------------------------------------------------------------
    // Half-open → Open after 5 consecutive failures
    // -------------------------------------------------------------------------

    test('5 consecutive failures in halfOpen transition to open', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 5; i++) {
        cb.recordFailure(); // 5 failures while halfOpen
      }

      expect(cb.state, SyncCbState.open);
    });

    test('4 consecutive failures in halfOpen do not transition to open', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 4; i++) {
        cb.recordFailure();
      }

      expect(cb.state, SyncCbState.halfOpen);
    });

    test('canRequest is false when open', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }

      expect(cb.canRequest, isFalse);
    });

    // -------------------------------------------------------------------------
    // Failure counter resets on success
    // -------------------------------------------------------------------------

    test('failure counter resets after success — 4 failures, then success, then 4 more stay halfOpen', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 4; i++) {
        cb.recordFailure(); // 4 failures in halfOpen
      }
      cb.recordSuccess(); // → closed, counter reset

      // Re-enter halfOpen
      cb.recordFailure(); // closed → halfOpen

      // 4 more failures should NOT open the CB (counter was reset)
      for (var i = 0; i < 4; i++) {
        cb.recordFailure();
      }

      expect(cb.state, SyncCbState.halfOpen);
    });

    // -------------------------------------------------------------------------
    // triggerManualSync: Open → Half-open
    // -------------------------------------------------------------------------

    test('triggerManualSync when open transitions to halfOpen', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      } // → open

      cb.triggerManualSync();

      expect(cb.state, SyncCbState.halfOpen);
    });

    test('triggerManualSync resets failure counter — subsequent success closes CB', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      } // → open
      cb.triggerManualSync(); // → halfOpen (counter reset)

      cb.recordSuccess(); // → closed

      expect(cb.state, SyncCbState.closed);
    });

    test('triggerManualSync when closed is a no-op', () {
      cb.triggerManualSync();

      expect(cb.state, SyncCbState.closed);
    });

    test('triggerManualSync when halfOpen is a no-op', () {
      cb.recordFailure(); // closed → halfOpen
      cb.triggerManualSync();

      expect(cb.state, SyncCbState.halfOpen);
    });

    // -------------------------------------------------------------------------
    // Full cycle: Closed → HalfOpen → Open → HalfOpen → Closed
    // -------------------------------------------------------------------------

    test('full cycle: closed → halfOpen → open → halfOpen → closed', () {
      expect(cb.state, SyncCbState.closed);

      cb.recordFailure();
      expect(cb.state, SyncCbState.halfOpen);

      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }
      expect(cb.state, SyncCbState.open);

      cb.triggerManualSync();
      expect(cb.state, SyncCbState.halfOpen);

      cb.recordSuccess();
      expect(cb.state, SyncCbState.closed);
    });
  });

  group('syncCircuitBreakerProvider', () {
    test('starts in closed state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(syncCircuitBreakerProvider), SyncCbState.closed);
    });

    test('notifier canRequest is true initially', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(syncCircuitBreakerProvider.notifier).canRequest, isTrue);
    });

    test('state updates are observed via provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(syncCircuitBreakerProvider.notifier).recordFailure();

      expect(container.read(syncCircuitBreakerProvider), SyncCbState.halfOpen);
    });
  });
}

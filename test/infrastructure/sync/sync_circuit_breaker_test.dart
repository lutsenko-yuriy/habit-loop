import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';

import '../remote_config/fake_remote_config_service.dart';

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
      expect(cb.state, SyncCircuitBreakerState.closed);
    });

    test('canRequest is true when closed', () {
      expect(cb.canRequest, isTrue);
    });

    // -------------------------------------------------------------------------
    // Closed → Half-open on first failure
    // -------------------------------------------------------------------------

    test('recordFailure when closed transitions to halfOpen', () {
      cb.recordFailure();

      expect(cb.state, SyncCircuitBreakerState.halfOpen);
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

      expect(cb.state, SyncCircuitBreakerState.closed);
    });

    test('recordSuccess when closed is a no-op', () {
      cb.recordSuccess();

      expect(cb.state, SyncCircuitBreakerState.closed);
    });

    // -------------------------------------------------------------------------
    // Half-open → Open after 5 consecutive failures
    // -------------------------------------------------------------------------

    test('5 consecutive failures in halfOpen transition to open', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 5; i++) {
        cb.recordFailure(); // 5 failures while halfOpen
      }

      expect(cb.state, SyncCircuitBreakerState.open);
    });

    test('4 consecutive failures in halfOpen do not transition to open', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 4; i++) {
        cb.recordFailure();
      }

      expect(cb.state, SyncCircuitBreakerState.halfOpen);
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

      expect(cb.state, SyncCircuitBreakerState.halfOpen);
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

      expect(cb.state, SyncCircuitBreakerState.halfOpen);
    });

    test('triggerManualSync resets failure counter — subsequent success closes CB', () {
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      } // → open
      cb.triggerManualSync(); // → halfOpen (counter reset)

      cb.recordSuccess(); // → closed

      expect(cb.state, SyncCircuitBreakerState.closed);
    });

    test('triggerManualSync when closed is a no-op', () {
      cb.triggerManualSync();

      expect(cb.state, SyncCircuitBreakerState.closed);
    });

    test('triggerManualSync when halfOpen is a no-op', () {
      cb.recordFailure(); // closed → halfOpen
      cb.triggerManualSync();

      expect(cb.state, SyncCircuitBreakerState.halfOpen);
    });

    // -------------------------------------------------------------------------
    // Custom maxConsecutiveFailures threshold
    // -------------------------------------------------------------------------

    test('constructor accepts custom maxConsecutiveFailures', () {
      final custom = SyncCircuitBreaker(maxConsecutiveFailures: 3);
      addTearDown(custom.dispose);

      expect(custom.state, SyncCircuitBreakerState.closed);
    });

    test('opens after custom threshold of 3 failures in halfOpen', () {
      final custom = SyncCircuitBreaker(maxConsecutiveFailures: 3);
      addTearDown(custom.dispose);

      custom.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 3; i++) {
        custom.recordFailure(); // 3 consecutive failures in halfOpen
      }

      expect(custom.state, SyncCircuitBreakerState.open);
    });

    test('does not open before custom threshold — 2 of 3 failures stays halfOpen', () {
      final custom = SyncCircuitBreaker(maxConsecutiveFailures: 3);
      addTearDown(custom.dispose);

      custom.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 2; i++) {
        custom.recordFailure();
      }

      expect(custom.state, SyncCircuitBreakerState.halfOpen);
    });

    test('default threshold of 5 is preserved when no argument supplied', () {
      // Re-validates existing behaviour after constructor signature change.
      cb.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 4; i++) {
        cb.recordFailure(); // 4 failures — not yet open
      }

      expect(cb.state, SyncCircuitBreakerState.halfOpen);

      cb.recordFailure(); // 5th — should open
      expect(cb.state, SyncCircuitBreakerState.open);
    });

    // -------------------------------------------------------------------------
    // Full cycle: Closed → HalfOpen → Open → HalfOpen → Closed
    // -------------------------------------------------------------------------

    test('full cycle: closed → halfOpen → open → halfOpen → closed', () {
      expect(cb.state, SyncCircuitBreakerState.closed);

      cb.recordFailure();
      expect(cb.state, SyncCircuitBreakerState.halfOpen);

      for (var i = 0; i < 5; i++) {
        cb.recordFailure();
      }
      expect(cb.state, SyncCircuitBreakerState.open);

      cb.triggerManualSync();
      expect(cb.state, SyncCircuitBreakerState.halfOpen);

      cb.recordSuccess();
      expect(cb.state, SyncCircuitBreakerState.closed);
    });
  });

  group('syncCircuitBreakerProvider', () {
    test('starts in closed state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(syncCircuitBreakerProvider), SyncCircuitBreakerState.closed);
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

      expect(container.read(syncCircuitBreakerProvider), SyncCircuitBreakerState.halfOpen);
    });

    test('reads threshold from RemoteConfigService — opens after 3 failures with RC threshold=3', () {
      final rc = FakeRemoteConfigService(overrides: {'sync_max_consecutive_failures': 3});
      final container = ProviderContainer(
        overrides: [remoteConfigServiceProvider.overrideWithValue(rc)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncCircuitBreakerProvider.notifier);
      notifier.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 3; i++) {
        notifier.recordFailure();
      }

      expect(container.read(syncCircuitBreakerProvider), SyncCircuitBreakerState.open);
    });

    test('with default RC returns 5, does not open after 4 halfOpen failures', () {
      // FakeRemoteConfigService falls back to RemoteConfigDefaults.all → 5
      final rc = FakeRemoteConfigService();
      final container = ProviderContainer(
        overrides: [remoteConfigServiceProvider.overrideWithValue(rc)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncCircuitBreakerProvider.notifier);
      notifier.recordFailure(); // closed → halfOpen
      for (var i = 0; i < 4; i++) {
        notifier.recordFailure();
      }

      expect(container.read(syncCircuitBreakerProvider), SyncCircuitBreakerState.halfOpen);
    });
  });
}

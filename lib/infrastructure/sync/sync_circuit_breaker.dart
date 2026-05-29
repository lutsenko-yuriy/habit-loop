import 'package:flutter_riverpod/flutter_riverpod.dart';

/// States of the sync circuit breaker.
///
/// - [closed] — normal operation; all sync requests flow through.
/// - [halfOpen] — tentative; requests are still allowed but consecutive failures
///   are counted toward the [SyncCircuitBreaker._maxConsecutiveFailures] limit.
/// - [open] — suspended; no automatic sync requests are made. Only a manual
///   trigger via [SyncCircuitBreaker.triggerManualSync] can move back to
///   [halfOpen].
enum SyncCircuitBreakerState { closed, halfOpen, open }

/// Circuit breaker that governs all Firestore network requests.
///
/// State machine:
/// - Closed → Half-open on any failure.
/// - Half-open → Closed on success; → Open after [_maxConsecutiveFailures]
///   consecutive failures.
/// - Open → Half-open only when the user manually triggers sync via
///   [triggerManualSync].
///
/// CB state is held in memory only and resets to [SyncCircuitBreakerState.closed] on every
/// app restart, giving the app a clean probe opportunity on each launch.
///
/// **Callers:**
/// - WU4 write-through sync service — checks [canRequest] before each Firestore
///   write; calls [recordSuccess] on success and [recordFailure] on error.
/// - WU5 pull-on-start sync service — same pattern for Firestore reads.
/// - WU6 sync-status UI — watches [syncCircuitBreakerProvider] to display sync
///   health and calls [triggerManualSync] when the user taps the retry button.
class SyncCircuitBreaker extends StateNotifier<SyncCircuitBreakerState> {
  final int _maxConsecutiveFailures;

  int _consecutiveFailures = 0;

  /// Creates a [SyncCircuitBreaker] with an optional [maxConsecutiveFailures]
  /// threshold.
  ///
  /// The threshold controls how many consecutive Firestore failures in the
  /// half-open state are allowed before the breaker trips to open. Defaults to
  /// 5 (matching `RemoteConfigDefaults.syncMaxConsecutiveFailures`).
  ///
  /// In production, [syncCircuitBreakerProvider] reads the threshold from
  /// Remote Config so it can be tuned without a new release.
  SyncCircuitBreaker({int maxConsecutiveFailures = 5})
      : _maxConsecutiveFailures = maxConsecutiveFailures,
        super(SyncCircuitBreakerState.closed);

  /// Whether a sync request is currently permitted.
  ///
  /// Returns `false` only in [SyncCircuitBreakerState.open]; both [SyncCircuitBreakerState.closed] and
  /// [SyncCircuitBreakerState.halfOpen] allow requests.
  bool get canRequest => state != SyncCircuitBreakerState.open;

  /// The current circuit breaker state, exposed for external callers that need
  /// to read the state without subclassing [StateNotifier].
  SyncCircuitBreakerState get currentState => state;

  /// Records a successful Firestore operation.
  ///
  /// - [halfOpen] → [closed]: the service is healthy again, counter reset.
  /// - [closed]: no-op (success is the expected outcome).
  void recordSuccess() {
    if (state == SyncCircuitBreakerState.halfOpen) {
      _consecutiveFailures = 0;
      state = SyncCircuitBreakerState.closed;
    }
  }

  /// Records a failed Firestore operation.
  ///
  /// - [closed] → [halfOpen]: first failure, counter cleared.
  /// - [halfOpen]: failure counter incremented; transitions to [open] once
  ///   [_maxConsecutiveFailures] is reached.
  /// - [open]: no-op (callers should not invoke this when [canRequest] is false).
  void recordFailure() {
    switch (state) {
      case SyncCircuitBreakerState.closed:
        _consecutiveFailures = 0;
        state = SyncCircuitBreakerState.halfOpen;
      case SyncCircuitBreakerState.halfOpen:
        _consecutiveFailures++;
        if (_consecutiveFailures >= _maxConsecutiveFailures) {
          state = SyncCircuitBreakerState.open;
        }
      case SyncCircuitBreakerState.open:
        break;
    }
  }

  /// Transitions from [open] to [halfOpen] and resets the failure counter,
  /// allowing one new probe pass. Called from the sync-status UI (WU6) when
  /// the user manually requests a sync retry.
  ///
  /// No-op when the CB is not in [SyncCircuitBreakerState.open].
  void triggerManualSync() {
    if (state == SyncCircuitBreakerState.open) {
      _consecutiveFailures = 0;
      state = SyncCircuitBreakerState.halfOpen;
    }
  }
}

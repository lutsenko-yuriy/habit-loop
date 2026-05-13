import 'package:flutter_riverpod/flutter_riverpod.dart';

/// States of the sync circuit breaker.
///
/// - [closed] — normal operation; all sync requests flow through.
/// - [halfOpen] — tentative; requests are still allowed but consecutive failures
///   are counted toward the [SyncCircuitBreaker._maxConsecutiveFailures] limit.
/// - [open] — suspended; no automatic sync requests are made. Only a manual
///   trigger via [SyncCircuitBreaker.triggerManualSync] can move back to
///   [halfOpen].
enum SyncCbState { closed, halfOpen, open }

/// Circuit breaker that governs all Firestore network requests.
///
/// State machine:
/// - Closed → Half-open on any failure.
/// - Half-open → Closed on success; → Open after [_maxConsecutiveFailures]
///   consecutive failures.
/// - Open → Half-open only when the user manually triggers sync via
///   [triggerManualSync].
///
/// CB state is held in memory only and resets to [SyncCbState.closed] on every
/// app restart, giving the app a clean probe opportunity on each launch.
///
/// All sync operations (WU4, WU5) must check [canRequest] before making a
/// network call and call [recordSuccess] / [recordFailure] based on the result.
class SyncCircuitBreaker extends StateNotifier<SyncCbState> {
  static const int _maxConsecutiveFailures = 5;

  int _consecutiveFailures = 0;

  SyncCircuitBreaker() : super(SyncCbState.closed);

  /// Whether a sync request is currently permitted.
  ///
  /// Returns `false` only in [SyncCbState.open]; both [SyncCbState.closed] and
  /// [SyncCbState.halfOpen] allow requests.
  bool get canRequest => state != SyncCbState.open;

  /// Records a successful Firestore operation.
  ///
  /// - [halfOpen] → [closed]: the service is healthy again, counter reset.
  /// - [closed]: no-op (success is the expected outcome).
  void recordSuccess() {
    if (state == SyncCbState.halfOpen) {
      _consecutiveFailures = 0;
      state = SyncCbState.closed;
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
      case SyncCbState.closed:
        _consecutiveFailures = 0;
        state = SyncCbState.halfOpen;
      case SyncCbState.halfOpen:
        _consecutiveFailures++;
        if (_consecutiveFailures >= _maxConsecutiveFailures) {
          state = SyncCbState.open;
        }
      case SyncCbState.open:
        break;
    }
  }

  /// Transitions from [open] to [halfOpen] and resets the failure counter,
  /// allowing one new probe pass. Called from the sync-status UI (WU6) when
  /// the user manually requests a sync retry.
  ///
  /// No-op when the CB is not in [SyncCbState.open].
  void triggerManualSync() {
    if (state == SyncCbState.open) {
      _consecutiveFailures = 0;
      state = SyncCbState.halfOpen;
    }
  }
}

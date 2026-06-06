import 'package:flutter_riverpod/flutter_riverpod.dart';

/// closed = normal; halfOpen = tentative (requests allowed, failures counted);
/// open = suspended (only [triggerManualSync] can return to halfOpen).
enum SyncCircuitBreakerState { closed, halfOpen, open }

/// Governs all Firestore network requests.
///
/// State transitions: Closed → HalfOpen on failure; HalfOpen → Closed on
/// success, → Open after [_maxConsecutiveFailures] consecutive failures;
/// Open → HalfOpen only via [triggerManualSync].
///
/// In-memory only — resets to Closed on every app restart.
class SyncCircuitBreaker extends StateNotifier<SyncCircuitBreakerState> {
  final int _maxConsecutiveFailures;

  int _consecutiveFailures = 0;

  SyncCircuitBreaker({int maxConsecutiveFailures = 5})
      : _maxConsecutiveFailures = maxConsecutiveFailures,
        super(SyncCircuitBreakerState.closed);

  // false only in open state — closed and halfOpen both allow requests.
  bool get canRequest => state != SyncCircuitBreakerState.open;

  SyncCircuitBreakerState get currentState => state;

  void recordSuccess() {
    if (state == SyncCircuitBreakerState.halfOpen) {
      _consecutiveFailures = 0;
      state = SyncCircuitBreakerState.closed;
    }
  }

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

  // No-op unless in open state.
  void triggerManualSync() {
    if (state == SyncCircuitBreakerState.open) {
      _consecutiveFailures = 0;
      state = SyncCircuitBreakerState.halfOpen;
    }
  }
}

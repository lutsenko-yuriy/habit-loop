/// Re-entrancy lock + minimum-interval gate shared between
/// `AppLifecycleReconciler`'s two triggers (app foreground,
/// `SyncService.pullCompleted`) so a reconciliation pass can't overlap
/// itself or fire twice back-to-back (HAB-254 WU3).
class ReconciliationThrottle {
  ReconciliationThrottle({this.minInterval = const Duration(seconds: 30)});

  final Duration minInterval;

  bool _running = false;
  DateTime? _lastStartedAt;

  /// True while a run is in flight (between [tryStart]/[forceStart] and [finish]).
  bool get isRunning => _running;

  /// Returns whether a run may start now, and if so marks one as started.
  /// Blocked while a previous run hasn't called [finish] yet, or while
  /// [minInterval] hasn't elapsed since the last run started.
  bool tryStart(DateTime now) {
    if (_running) return false;
    final lastStartedAt = _lastStartedAt;
    if (lastStartedAt != null && now.difference(lastStartedAt) < minInterval) return false;

    _running = true;
    _lastStartedAt = now;
    return true;
  }

  /// Unconditionally starts a run, bypassing the [minInterval] check —
  /// for a trigger that was already queued behind [isRunning] rather than
  /// a newly-arriving one. [minInterval] exists to rate-limit distinct new
  /// triggers, not to delay one that was already waiting its turn for the
  /// re-entrancy lock to clear.
  void forceStart(DateTime now) {
    _running = true;
    _lastStartedAt = now;
  }

  /// Marks the current run complete, freeing the re-entrancy lock.
  void finish() {
    _running = false;
  }
}

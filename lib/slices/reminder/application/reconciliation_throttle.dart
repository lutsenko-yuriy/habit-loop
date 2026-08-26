/// Re-entrancy lock + minimum-interval gate shared between
/// `AppLifecycleReconciler`'s two triggers (app foreground,
/// `SyncService.pullCompleted`) so a reconciliation pass can't overlap
/// itself or fire twice back-to-back (HAB-254 WU3).
class ReconciliationThrottle {
  ReconciliationThrottle({this.minInterval = const Duration(seconds: 30)});

  final Duration minInterval;

  bool _running = false;
  DateTime? _lastStartedAt;

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

  /// Marks the current run complete, freeing the re-entrancy lock.
  void finish() {
    _running = false;
  }
}

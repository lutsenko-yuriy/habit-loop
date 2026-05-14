/// UI-layer sync state derived from auth state, circuit breaker state, and
/// device connectivity. Priority order (highest to lowest):
/// [noInternet] > [connecting] > [notLinked] > [suspended] > [degraded] > [synced]
enum SyncUiState {
  /// Device has no network connection.
  noInternet,

  /// Auth is still initialising or the first sync pull is in progress.
  connecting,

  /// User is signed in anonymously — data is local only.
  notLinked,

  /// Circuit breaker is open — automatic sync has stopped.
  suspended,

  /// Circuit breaker is half-open — last request failed, probing.
  degraded,

  /// Everything is healthy.
  synced,
}

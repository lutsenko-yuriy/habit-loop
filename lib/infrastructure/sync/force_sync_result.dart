/// Result of a user-triggered full sync ([SyncService.forceSyncAll]).
class ForceSyncResult {
  const ForceSyncResult({
    required this.attempted,
    required this.pactsFailed,
    required this.showupsFailed,
    this.pactBreaksFailed = 0,
  });

  /// Total records marked dirty before the flush pass.
  final int attempted;

  /// Pacts still dirty after the flush (failed to upload).
  final int pactsFailed;

  /// Showups still dirty after the flush (failed to upload).
  final int showupsFailed;

  /// Pact breaks still dirty after the flush (failed to upload).
  final int pactBreaksFailed;

  int get failed => pactsFailed + showupsFailed + pactBreaksFailed;
  int get succeeded => attempted - failed;
}

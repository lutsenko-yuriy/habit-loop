/// Result of a user-triggered full sync ([SyncService.forceSyncAll]).
class ForceSyncResult {
  const ForceSyncResult({
    required this.attempted,
    required this.pactsFailed,
    required this.showupsFailed,
  });

  /// Total records marked dirty before the flush pass.
  final int attempted;

  /// Pacts still dirty after the flush (failed to upload).
  final int pactsFailed;

  /// Showups still dirty after the flush (failed to upload).
  final int showupsFailed;

  int get failed => pactsFailed + showupsFailed;
  int get succeeded => attempted - failed;
}

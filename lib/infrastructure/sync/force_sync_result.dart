/// Result of a user-triggered full sync ([SyncService.forceSyncAll]).
class ForceSyncResult {
  const ForceSyncResult({
    required this.attempted,
    required this.pactsFailed,
    required this.showupsFailed,
    this.pactBreaksFailed = 0,
    this.userProfileFailed = 0,
  });

  /// Total records marked dirty before the flush pass.
  final int attempted;

  /// Pacts still dirty after the flush (failed to upload).
  final int pactsFailed;

  /// Showups still dirty after the flush (failed to upload).
  final int showupsFailed;

  /// Pact breaks still dirty after the flush (failed to upload).
  final int pactBreaksFailed;

  /// `1` if the user profile is still dirty after the flush (failed to
  /// upload), `0` otherwise. There is at most one profile per user, so this
  /// is a 0/1 count rather than a list length.
  final int userProfileFailed;

  int get failed => pactsFailed + showupsFailed + pactBreaksFailed + userProfileFailed;
  int get succeeded => attempted - failed;
}

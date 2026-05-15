import 'package:habit_loop/domain/showup/showup.dart';

/// Sync-layer persistence contract for [Showup] records.
///
/// Implemented by [SqliteShowupRepository] alongside [ShowupRepository]. Only
/// the sync service (WU4) calls these methods — view models and application
/// services use [ShowupRepository] exclusively and are unaware of sync state.
abstract class ShowupSyncRepository {
  /// Returns all showups whose local state has not yet been flushed to Firestore.
  Future<List<Showup>> getDirtyShowups();

  /// Marks [showupId] as successfully synced: sets `dirty=0` and
  /// `synced_at` to [syncedAt] in the local database.
  Future<void> markShowupSynced(String showupId, DateTime syncedAt);

  /// Returns the `synced_at` timestamp for [showupId], or `null` if the showup
  /// has local unsync'd changes (`dirty=1`) or has never been synced.
  ///
  /// Used by the pull-on-start sync (WU5) to compare remote vs local timestamps.
  Future<DateTime?> getShowupSyncedAt(String showupId);

  /// Marks every showup in the local database as dirty (`dirty=1, synced_at=NULL`).
  ///
  /// Called by [SyncService.forceSyncAll] after a Firebase UID change so that
  /// all local records are re-uploaded under the new UID regardless of their
  /// previous sync state.
  Future<void> markAllShowupsDirty();
}

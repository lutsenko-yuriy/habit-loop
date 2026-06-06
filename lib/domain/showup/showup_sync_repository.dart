import 'package:habit_loop/domain/showup/showup.dart';

/// Sync-layer persistence for [Showup] records.
/// Only the sync service calls these — view models and application services use [ShowupRepository].
abstract class ShowupSyncRepository {
  /// Returns all showups whose local state has not yet been flushed to Firestore.
  Future<List<Showup>> getDirtyShowups();

  /// Marks [showupId] as successfully synced: sets `dirty=0` and
  /// `synced_at` to [syncedAt] in the local database.
  Future<void> markShowupSynced(String showupId, DateTime syncedAt);

  /// Returns the `synced_at` timestamp for [showupId], or `null` if dirty or never synced.
  Future<DateTime?> getShowupSyncedAt(String showupId);

  /// Marks every showup dirty (`dirty=1, synced_at=NULL`).
  /// Called after a Firebase UID change so all records are re-uploaded under the new UID.
  Future<void> markAllShowupsDirty();
}

import 'package:habit_loop/domain/pact/pact.dart';

/// Sync-layer persistence for [Pact] records.
/// Only the sync service calls these — view models and application services use [PactRepository].
abstract class PactSyncRepository {
  /// Returns all pacts whose local state has not yet been flushed to Firestore.
  Future<List<Pact>> getDirtyPacts();

  /// Marks [pactId] as successfully synced: sets `dirty=0` and
  /// `synced_at` to [syncedAt] in the local database.
  Future<void> markPactSynced(String pactId, DateTime syncedAt);

  /// Returns the `synced_at` timestamp for [pactId], or `null` if dirty or never synced.
  Future<DateTime?> getPactSyncedAt(String pactId);

  /// Marks every pact dirty (`dirty=1, synced_at=NULL`).
  /// Called after a Firebase UID change so all records are re-uploaded under the new UID.
  Future<void> markAllPactsDirty();
}

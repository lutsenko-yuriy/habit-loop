import 'package:habit_loop/domain/pact/pact_break.dart';

/// Sync-layer persistence for [PactBreak] records.
/// Only the sync service calls these — application code uses [PactBreakRepository].
abstract class PactBreakSyncRepository {
  /// Returns all pact breaks whose local state has not yet been flushed to Firestore.
  Future<List<PactBreak>> getDirtyPactBreaks();

  /// Marks [pactBreakId] as successfully synced: sets `dirty=0` and
  /// `synced_at` to [syncedAt] in the local database.
  Future<void> markPactBreakSynced(String pactBreakId, DateTime syncedAt);

  /// Returns the `synced_at` timestamp for [pactBreakId], or `null` if dirty or never synced.
  Future<DateTime?> getPactBreakSyncedAt(String pactBreakId);

  /// Marks every pact break dirty (`dirty=1, synced_at=NULL`).
  /// Called after a Firebase UID change so all records are re-uploaded under the new UID.
  Future<void> markAllPactBreaksDirty();
}

import 'package:habit_loop/domain/pact/pact.dart';

/// Sync-layer persistence contract for [Pact] records.
///
/// Implemented by [SqlitePactRepository] alongside [PactRepository]. Only the
/// sync service (WU4) calls these methods — view models and application
/// services use [PactRepository] exclusively and are unaware of sync state.
abstract class PactSyncRepository {
  /// Returns all pacts whose local state has not yet been flushed to Firestore.
  Future<List<Pact>> getDirtyPacts();

  /// Marks [pactId] as successfully synced: sets `dirty=0` and
  /// `synced_at` to [syncedAt] in the local database.
  Future<void> markPactSynced(String pactId, DateTime syncedAt);
}

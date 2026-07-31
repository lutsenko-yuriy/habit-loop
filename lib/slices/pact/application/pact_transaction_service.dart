import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';

/// Abstract interface for atomic write paths spanning both the `pacts` and `showups` tables.
/// Keeping it abstract lets services depend on this without importing sqflite.
abstract class PactTransactionService {
  /// Atomically creates [pact] and all [showups].
  ///
  /// Throws if either insert fails (e.g. duplicate ID). Implementations must
  /// guarantee that on failure the database is left in a consistent state (no
  /// orphaned pact row, no partial showup inserts).
  Future<void> savePactWithShowups(Pact pact, List<Showup> showups);

  /// Atomically updates the pact row and deletes its showups scheduled after
  /// [now].
  ///
  /// Used by the stop-pact flow: the pact status update and the showup
  /// deletion are wrapped in a single operation so either both succeed or
  /// both are rolled back. Showups at or before [now] are kept — they are
  /// real history (done/failed, or a showup whose slot has already begun)
  /// and must survive the stop so stats and the timeline stay intact
  /// (HAB-208). Only showups that would never happen — scheduled strictly
  /// after [now] — are removed.
  Future<void> stopPactTransaction({
    required Pact updatedPact,
    required String pactId,
    required DateTime now,
  });
}

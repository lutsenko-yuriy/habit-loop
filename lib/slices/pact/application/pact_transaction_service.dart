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

  /// Atomically updates the pact row and deletes its still-pending future
  /// showups (scheduled after [now]).
  ///
  /// Kept: showups at/before [now], plus any showup already marked
  /// done/failed regardless of time — both are real history the stop must
  /// not lose (HAB-208). Only pending showups that would never happen are
  /// removed.
  Future<void> stopPactTransaction({
    required Pact updatedPact,
    required String pactId,
    required DateTime now,
  });
}

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

  /// Atomically updates the pact row and deletes all showups for the pact.
  ///
  /// Used by the stop-pact flow: the pact status update and the showup deletion
  /// are wrapped in a single operation so either both succeed or both are rolled
  /// back.
  Future<void> stopPactTransaction({
    required Pact updatedPact,
    required String pactId,
  });
}

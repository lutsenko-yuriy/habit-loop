import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';

/// Abstract interface for atomic write paths that span both the `pacts` and
/// `showups` tables.
///
/// Two concrete implementations exist:
/// - [SqlitePactTransactionService] — production implementation backed by
///   sqflite; wraps both mutations in a single `db.transaction()` call.
/// - [InMemoryPactTransactionService] — test double backed by in-memory
///   repositories; falls back to the sequential save + manual rollback path.
///
/// Keeping the interface abstract allows view models and application services to
/// depend on [PactTransactionService] without importing sqflite.
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

/// Provides the [PactTransactionService] to the app.
///
/// Throws [UnimplementedError] by default — must be overridden in `main.dart`
/// with a [SqlitePactTransactionService] instance, and in tests with an
/// [InMemoryPactTransactionService].
final pactTransactionServiceProvider = Provider<PactTransactionService>((ref) {
  throw UnimplementedError('pactTransactionServiceProvider must be overridden in main.dart');
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/persistence/pact_mapper.dart';
import 'package:habit_loop/infrastructure/persistence/showup_mapper.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the atomic write paths for pact creation and pact termination.
///
/// Both operations span the `pacts` and `showups` tables. Using a single
/// `db.transaction()` block guarantees atomicity: if any individual INSERT or
/// UPDATE fails the whole operation rolls back, leaving the database in a
/// consistent state.
///
/// This class is the fix for HAB-16: previously `PactCreationViewModel` called
/// `PactRepository.savePact` and `ShowupRepository.saveShowups` as two separate
/// operations with a manual `deletePact` rollback on failure. The manual rollback
/// could mask the original error and left a window where a network interruption
/// produced an orphaned pact with no showups.
class PactTransactionService {
  const PactTransactionService(this._db);

  final Database _db;

  /// Atomically inserts [pact] and all [showups] in a single transaction.
  ///
  /// Sets the pact's `total_showups` column to `showups.length`. This value is
  /// written here — not by [PactMapper.toRow] — because only the caller knows
  /// the exact count of showups being persisted.
  ///
  /// Throws if either insert fails (e.g. duplicate ID). sqflite rolls back the
  /// transaction automatically on any exception, so the database is always left
  /// in a consistent state.
  Future<void> savePactWithShowups(Pact pact, List<Showup> showups) async {
    await _db.transaction((txn) async {
      final row = PactMapper.toRow(pact);
      row['total_showups'] = showups.length;
      await txn.insert('pacts', row, conflictAlgorithm: ConflictAlgorithm.fail);
      for (final showup in showups) {
        await txn.insert(
          'showups',
          ShowupMapper.toRow(showup),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
      }
    });
  }

  /// Atomically updates the pact row (status, actual_end_date, stop_reason) and
  /// deletes all showups for the pact in a single transaction.
  ///
  /// This is the atomic stop-pact path that replaces the two-step
  /// `updatePact` + `deleteShowupsForPact` sequence that existed in
  /// `PactStatsService.stopPact`. Both mutations are now wrapped in one
  /// `db.transaction()` so either both succeed or both are rolled back.
  ///
  /// Only the mutable columns are written (via [PactMapper.toUpdateRow]) —
  /// `scheduled_end_date` and `total_showups` are intentionally excluded and
  /// preserved intact.
  Future<void> stopPactTransaction({
    required Pact updatedPact,
    required String pactId,
  }) async {
    await _db.transaction((txn) async {
      await txn.update(
        'pacts',
        PactMapper.toUpdateRow(updatedPact),
        where: 'id = ?',
        whereArgs: [pactId],
      );
      await txn.delete('showups', where: 'pact_id = ?', whereArgs: [pactId]);
    });
  }
}

/// Provides the [PactTransactionService] to the app.
///
/// Throws by default — must be overridden in [ProviderScope] with a real
/// [Database] instance before any code reads this provider. The override is
/// installed in WU4 (provider wiring in `main.dart`).
///
/// This follows the same pattern as [pactRepositoryProvider] and
/// [showupRepositoryProvider].
final pactTransactionServiceProvider = Provider<PactTransactionService>((ref) {
  throw UnimplementedError('Override pactTransactionServiceProvider with a real Database instance');
});

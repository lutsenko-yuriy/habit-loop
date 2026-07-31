import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/persistence/pact_mapper.dart';
import 'package:habit_loop/infrastructure/persistence/showup_mapper.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [PactTransactionService].
///
/// Both [savePactWithShowups] and [stopPactTransaction] wrap their mutations in
/// a single `db.transaction()` call so either everything commits or nothing
/// does. sqflite rolls back the transaction automatically on any exception.
class SqlitePactTransactionService implements PactTransactionService {
  const SqlitePactTransactionService(this._db);

  final Database _db;

  /// Atomically inserts [pact] and all [showups] in a single transaction.
  ///
  /// Sets the pact's `total_showups` column to `showups.length`. This value is
  /// written here — not by [PactMapper.toRow] — because only the caller knows
  /// the exact count of showups being persisted.
  ///
  /// Uses [ConflictAlgorithm.fail] so any duplicate-ID error surfaces
  /// immediately rather than silently overwriting data.
  @override
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

  /// Updates the pact row and deletes only its pending-and-future showups —
  /// see [PactTransactionService.stopPactTransaction] for why.
  ///
  /// Only mutable columns are written (via [PactMapper.toUpdateRow]);
  /// `scheduled_end_date`/`total_showups` are preserved untouched.
  @override
  Future<void> stopPactTransaction({
    required Pact updatedPact,
    required String pactId,
    required DateTime now,
  }) async {
    await _db.transaction((txn) async {
      final affected = await txn.update(
        'pacts',
        PactMapper.toUpdateRow(updatedPact),
        where: 'id = ?',
        whereArgs: [pactId],
      );
      if (affected == 0) {
        throw StateError('stopPactTransaction: pact $pactId not found');
      }
      await txn.delete(
        'showups',
        where: 'pact_id = ? AND scheduled_at > ? AND status = ?',
        whereArgs: [pactId, now.millisecondsSinceEpoch, 'pending'],
      );
    });
  }
}

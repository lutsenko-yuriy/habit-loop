import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_break_repository.dart';
import 'package:habit_loop/infrastructure/persistence/pact_break_mapper.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [PactBreakRepository].
///
/// Takes an open [Database] in its constructor. The database lifecycle is
/// managed by `HabitLoopDatabase`.
///
/// All [DateTime] fields are stored as epoch milliseconds and reconstructed
/// as **local-time** values via [PactBreakMapper].
///
/// The `dirty` and `synced_at` columns are managed internally by this class
/// and are not yet exposed through any sync interface — that lands in WU1.3.
class SqlitePactBreakRepository implements PactBreakRepository {
  const SqlitePactBreakRepository(this._db);

  final Database _db;

  static const _table = 'pact_breaks';

  @override
  Future<List<PactBreak>> getBreaksForPact(String pactId) async {
    final rows = await _db.query(_table, where: 'pact_id = ?', whereArgs: [pactId], orderBy: 'start_date ASC');
    return rows.map(PactBreakMapper.fromRow).toList();
  }

  @override
  Future<void> saveBreak(PactBreak pactBreak) async {
    final existing = await _db.query(_table, where: 'id = ?', whereArgs: [pactBreak.id]);
    if (existing.isNotEmpty) {
      throw ArgumentError('PactBreak with id "${pactBreak.id}" already exists.');
    }
    await _db.insert(_table, PactBreakMapper.toRow(pactBreak));
  }

  @override
  Future<void> updateBreak(PactBreak pactBreak) async {
    final existing = await _db.query(_table, where: 'id = ?', whereArgs: [pactBreak.id]);
    if (existing.isEmpty) {
      throw ArgumentError('PactBreak with id "${pactBreak.id}" not found.');
    }
    await _db.insert(_table, PactBreakMapper.toRow(pactBreak), conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

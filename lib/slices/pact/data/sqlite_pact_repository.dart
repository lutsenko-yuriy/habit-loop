import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/persistence/pact_mapper.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [PactRepository].
///
/// Takes an open [Database] in its constructor. The database lifecycle (open /
/// close, schema migrations) is managed by [HabitLoopDatabase] — this class
/// is purely concerned with SQL CRUD.
///
/// All [DateTime] fields are stored as epoch milliseconds and reconstructed
/// as **local-time** values via [PactMapper], preserving the invariant set by
/// [PactBuilder] that all dates are local-time.
class SqlitePactRepository implements PactRepository {
  const SqlitePactRepository(this._db);

  final Database _db;

  static const _table = 'pacts';

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Future<Pact?> getPactById(String id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PactMapper.fromRow(rows.first);
  }

  @override
  Future<List<Pact>> getAllPacts() async {
    final rows = await _db.query(_table);
    return rows.map(PactMapper.fromRow).toList();
  }

  @override
  Future<List<Pact>> getActivePacts() async {
    final rows = await _db.query(
      _table,
      where: 'status = ?',
      whereArgs: [_encodeStatus(PactStatus.active)],
    );
    return rows.map(PactMapper.fromRow).toList();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  @override
  Future<void> savePact(Pact pact) async {
    final existing = await getPactById(pact.id);
    if (existing != null) {
      throw ArgumentError('Pact with id "${pact.id}" already exists.');
    }
    await _db.insert(_table, PactMapper.toRow(pact));
  }

  @override
  Future<void> updatePact(Pact pact) async {
    final existing = await getPactById(pact.id);
    if (existing == null) {
      throw ArgumentError('Pact with id "${pact.id}" not found.');
    }
    // Use a targeted UPDATE so immutable columns (scheduled_end_date, total_showups,
    // schedule, etc.) are never overwritten — see PactMapper.toUpdateRow for the
    // exact set of mutable columns that are touched.
    await _db.update(
      _table,
      PactMapper.toUpdateRow(pact),
      where: 'id = ?',
      whereArgs: [pact.id],
    );
  }

  @override
  Future<void> deletePact(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static String _encodeStatus(PactStatus status) => switch (status) {
        PactStatus.active => 'active',
        PactStatus.stopped => 'stopped',
        PactStatus.completed => 'completed',
      };
}

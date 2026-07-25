import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_break_repository.dart';
import 'package:habit_loop/domain/pact/pact_break_sync_repository.dart';
import 'package:habit_loop/infrastructure/persistence/pact_break_mapper.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [PactBreakRepository] and [PactBreakSyncRepository].
///
/// Takes an open [Database] in its constructor. The database lifecycle is
/// managed by `HabitLoopDatabase`.
///
/// All [DateTime] fields are stored as epoch milliseconds and reconstructed
/// as **local-time** values via [PactBreakMapper].
class SqlitePactBreakRepository implements PactBreakRepository, PactBreakSyncRepository {
  const SqlitePactBreakRepository(this._db);

  final Database _db;

  static const _table = 'pact_breaks';

  @override
  Future<List<PactBreak>> getBreaksForPact(String pactId) async {
    final rows = await _db.query(_table, where: 'pact_id = ?', whereArgs: [pactId], orderBy: 'start_date ASC');
    return rows.map(PactBreakMapper.fromRow).toList();
  }

  @override
  Future<PactBreak?> getBreakById(String id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PactBreakMapper.fromRow(rows.first);
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

  @override
  Future<List<PactBreak>> getDirtyPactBreaks() async {
    final rows = await _db.query(_table, where: 'dirty = ?', whereArgs: [1]);
    return rows.map(PactBreakMapper.fromRow).toList();
  }

  @override
  Future<void> markPactBreakSynced(String pactBreakId, DateTime syncedAt) async {
    await _db.update(_table, {'dirty': 0, 'synced_at': syncedAt.millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [pactBreakId]);
  }

  @override
  Future<DateTime?> getPactBreakSyncedAt(String pactBreakId) async {
    final rows = await _db.query(_table, columns: ['dirty', 'synced_at'], where: 'id = ?', whereArgs: [pactBreakId]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    if ((row['dirty'] as int) == 1) return null; // dirty → unsync'd local changes
    final ms = row['synced_at'];
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((ms as int));
  }

  @override
  Future<void> markAllPactBreaksDirty() async {
    await _db.update(_table, {'dirty': 1, 'synced_at': null});
  }
}

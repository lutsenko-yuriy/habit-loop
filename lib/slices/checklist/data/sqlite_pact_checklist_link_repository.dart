import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link_repository.dart';
import 'package:habit_loop/infrastructure/persistence/pact_checklist_link_mapper.dart';
import 'package:sqflite/sqflite.dart';

class SqlitePactChecklistLinkRepository implements PactChecklistLinkRepository {
  const SqlitePactChecklistLinkRepository(this._db);

  final Database _db;

  static const _table = 'pact_checklist_links';

  @override
  Future<PactChecklistLink?> getForPact(String pactId) async {
    final rows = await _db.query(_table, where: 'pact_id = ?', whereArgs: [pactId]);
    return rows.isEmpty ? null : PactChecklistLinkMapper.fromRow(rows.first);
  }

  @override
  Future<Map<String, PactChecklistLink>> getForPacts(Iterable<String> pactIds) async {
    final ids = pactIds.toSet().toList();
    if (ids.isEmpty) return {};
    final result = <String, PactChecklistLink>{};
    // Chunked to stay under SQLite's bound-variable limit.
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      final rows = await _db.query(
        _table,
        where: 'pact_id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final link = PactChecklistLinkMapper.fromRow(row);
        result[link.pactId] = link;
      }
    }
    return result;
  }

  @override
  Future<void> upsert(PactChecklistLink link) async {
    await _db.insert(_table, PactChecklistLinkMapper.toRow(link), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String pactId) async {
    await _db.delete(_table, where: 'pact_id = ?', whereArgs: [pactId]);
  }
}

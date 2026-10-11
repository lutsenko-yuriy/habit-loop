import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/checklist_run_repository.dart';
import 'package:habit_loop/infrastructure/persistence/checklist_run_mapper.dart';
import 'package:habit_loop/slices/checklist/data/chunked_in_query.dart';
import 'package:sqflite/sqflite.dart';

class SqliteChecklistRunRepository implements ChecklistRunRepository {
  const SqliteChecklistRunRepository(this._db);

  final Database _db;

  static const _table = 'checklist_runs';

  @override
  Future<ChecklistRun?> getForShowup(String showupId) async {
    final rows = await _db.query(_table, where: 'showup_id = ?', whereArgs: [showupId]);
    return rows.isEmpty ? null : ChecklistRunMapper.fromRow(rows.first);
  }

  @override
  Future<Map<String, ChecklistRun>> getForShowups(Iterable<String> showupIds) async {
    final ids = showupIds.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await queryByIdsChunked(_db, _table, 'showup_id', ids);
    final entries = rows.map(ChecklistRunMapper.fromRow);
    return {for (final run in entries) run.showupId: run};
  }

  @override
  Future<ChecklistRun> upsertStarted({
    required String showupId,
    required String pactId,
    required String checklistId,
    required DateTime startedAt,
  }) {
    return _db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'showup_id = ?', whereArgs: [showupId]);
      if (rows.isNotEmpty) {
        final existing = ChecklistRunMapper.fromRow(rows.first);
        if (existing.isFinished) return existing;
      }
      final run = ChecklistRun(showupId: showupId, pactId: pactId, checklistId: checklistId, startedAt: startedAt);
      await txn.insert(_table, ChecklistRunMapper.toRow(run), conflictAlgorithm: ConflictAlgorithm.replace);
      return run;
    });
  }

  @override
  Future<ChecklistRun?> markFinished({
    required String showupId,
    required DateTime finishedAt,
    required ChecklistRunOutcome outcome,
  }) {
    return _db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'showup_id = ?', whereArgs: [showupId]);
      if (rows.isEmpty) return null;
      final existing = ChecklistRunMapper.fromRow(rows.first);
      if (existing.isFinished) return null;
      final finished = ChecklistRun(
        showupId: existing.showupId,
        pactId: existing.pactId,
        checklistId: existing.checklistId,
        startedAt: existing.startedAt,
        finishedAt: finishedAt,
        outcome: outcome,
      );
      await txn.update(
        _table,
        {'finished_at': finishedAt.millisecondsSinceEpoch, 'outcome': outcome.name},
        where: 'showup_id = ?',
        whereArgs: [showupId],
      );
      return finished;
    });
  }
}

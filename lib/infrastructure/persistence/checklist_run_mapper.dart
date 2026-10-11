import 'package:habit_loop/domain/checklist/checklist_run.dart';

/// Maps [ChecklistRun] to and from SQLite rows. Local-only: no sync columns.
abstract final class ChecklistRunMapper {
  static Map<String, dynamic> toRow(ChecklistRun run) => {
        'showup_id': run.showupId,
        'pact_id': run.pactId,
        'checklist_id': run.checklistId,
        'started_at': run.startedAt.millisecondsSinceEpoch,
        'finished_at': run.finishedAt?.millisecondsSinceEpoch,
        'outcome': run.outcome?.name,
      };

  /// Dates are restored as local-time [DateTime]s, matching the other mappers.
  static ChecklistRun fromRow(Map<String, dynamic> row) {
    final finished = row['finished_at'];
    final outcome = row['outcome'] as String?;
    return ChecklistRun(
      showupId: row['showup_id'] as String,
      pactId: row['pact_id'] as String,
      checklistId: row['checklist_id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch((row['started_at'] as num).toInt()),
      finishedAt: finished != null ? DateTime.fromMillisecondsSinceEpoch((finished as num).toInt()) : null,
      outcome: outcome == null ? null : ChecklistRunOutcome.values.asNameMap()[outcome],
    );
  }
}

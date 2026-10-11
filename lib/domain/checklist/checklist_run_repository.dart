import 'package:habit_loop/domain/checklist/checklist_run.dart';

abstract class ChecklistRunRepository {
  /// The run for [showupId], or `null` if none.
  Future<ChecklistRun?> getForShowup(String showupId);

  /// Runs for the given showups, keyed by showup id (showups without a run are absent).
  Future<Map<String, ChecklistRun>> getForShowups(Iterable<String> showupIds);

  /// Records a run start. Unknown showup/pact ids are accepted (no FK); the SQLite
  /// implementation removes rows when the owning showup/pact is deleted.
  /// Creates the run, or restarts an unfinished one by
  /// overwriting [startedAt] (and pact/checklist ids). A finished run is final
  /// and is returned unchanged. Returns the resulting run.
  Future<ChecklistRun> upsertStarted({
    required String showupId,
    required String pactId,
    required String checklistId,
    required DateTime startedAt,
  });

  /// Finishes the unfinished run for [showupId]. Returns the finished run, or
  /// `null` when there is no run or it is already finished (nothing changes).
  Future<ChecklistRun?> markFinished({
    required String showupId,
    required DateTime finishedAt,
    required ChecklistRunOutcome outcome,
  });
}

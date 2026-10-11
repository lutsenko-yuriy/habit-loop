import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/checklist_run_repository.dart';

// Fast in-memory fake used by unit tests that don't need SQLite fidelity.
class InMemoryChecklistRunRepository implements ChecklistRunRepository {
  final Map<String, ChecklistRun> _runs;

  InMemoryChecklistRunRepository([Iterable<ChecklistRun>? runs])
      : _runs = {for (final r in runs ?? const <ChecklistRun>[]) r.showupId: r};

  @override
  Future<ChecklistRun?> getForShowup(String showupId) async => _runs[showupId];

  @override
  Future<Map<String, ChecklistRun>> getForShowups(Iterable<String> showupIds) async => {
        for (final id in showupIds.toSet())
          if (_runs[id] != null) id: _runs[id]!,
      };

  @override
  Future<ChecklistRun> upsertStarted({
    required String showupId,
    required String pactId,
    required String checklistId,
    required DateTime startedAt,
  }) async {
    final existing = _runs[showupId];
    if (existing != null && existing.isFinished) return existing;
    return _runs[showupId] =
        ChecklistRun(showupId: showupId, pactId: pactId, checklistId: checklistId, startedAt: startedAt);
  }

  @override
  Future<ChecklistRun?> markFinished({
    required String showupId,
    required DateTime finishedAt,
    required ChecklistRunOutcome outcome,
  }) async {
    final existing = _runs[showupId];
    if (existing == null || existing.isFinished) return null;
    return _runs[showupId] = ChecklistRun(
      showupId: existing.showupId,
      pactId: existing.pactId,
      checklistId: existing.checklistId,
      startedAt: existing.startedAt,
      finishedAt: finishedAt,
      outcome: outcome,
    );
  }
}

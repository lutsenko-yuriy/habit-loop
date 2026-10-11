enum ChecklistRunOutcome { success, failure }

/// A checklist run for one showup. One per showup; [showupId] is the key.
///
/// Unfinished while [finishedAt] is null. Once finished the record is final.
class ChecklistRun {
  final String showupId;
  final String pactId;
  final String checklistId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final ChecklistRunOutcome? outcome;

  const ChecklistRun({
    required this.showupId,
    required this.pactId,
    required this.checklistId,
    required this.startedAt,
    this.finishedAt,
    this.outcome,
  });

  bool get isFinished => finishedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistRun &&
          showupId == other.showupId &&
          pactId == other.pactId &&
          checklistId == other.checklistId &&
          startedAt == other.startedAt &&
          finishedAt == other.finishedAt &&
          outcome == other.outcome;

  @override
  int get hashCode => Object.hash(showupId, pactId, checklistId, startedAt, finishedAt, outcome);
}

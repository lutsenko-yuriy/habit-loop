import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';

/// Whether marking a showup done is gated behind a checklist run.
enum ChecklistGate {
  /// No gate: mark done as usual.
  none,

  /// A run must finish before the showup can be marked done.
  runRequired,

  /// A run has finished (any outcome); mark done is available.
  unlocked;

  /// Derives the gate from the feature flag, Checklister install state, the
  /// pact's [link] and the showup's [run]. A finished run unlocks regardless
  /// of outcome. Redemption and on-break handling are the caller's concern.
  static ChecklistGate resolve({
    required bool flagEnabled,
    required bool checklisterInstalled,
    required PactChecklistLink? link,
    required ChecklistRun? run,
  }) {
    if (!flagEnabled || !checklisterInstalled || link == null) return none;
    return run != null && run.isFinished ? unlocked : runRequired;
  }
}

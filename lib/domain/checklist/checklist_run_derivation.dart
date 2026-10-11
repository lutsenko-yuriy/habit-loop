import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

/// Shared late-finish predicate used by the auto-fail sweeps, mirroring how
/// `BreakDerivation` is shared so read surfaces cannot diverge.
abstract final class ChecklistRunDerivation {
  static const lateFinishGrace = Duration(minutes: 15);

  /// True when auto-fail must be skipped for [showup]: it is still pending, a
  /// [run] was started no later than the window end, and [now] is within
  /// [grace] after the window end.
  static bool suppressesAutoFail({
    required Showup showup,
    required ChecklistRun? run,
    required DateTime now,
    Duration grace = lateFinishGrace,
  }) {
    if (run == null || showup.status != ShowupStatus.pending) return false;
    final windowEnd = showup.scheduledAt.add(showup.duration);
    if (run.startedAt.isAfter(windowEnd)) return false;
    return !now.isAfter(windowEnd.add(grace));
  }
}

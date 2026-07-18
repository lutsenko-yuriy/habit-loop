import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/showup/tail_zone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

class PactTimelineGrouper {
  const PactTimelineGrouper({
    this.noGroupingTailPeriodInDays = 7,
  });

  /// Showups whose scheduledAt falls within this many days before [now] are
  /// always shown individually (tail zone). Defaults to 7.
  final int noGroupingTailPeriodInDays;

  /// Groups [showups] (oldest-first, may include pending) into timeline milestones.
  ///
  /// [now] anchors the tail-zone cutoff; defaults to [DateTime.now()].
  /// [tailStartIndex] in the result is the authoritative tail boundary — do not infer
  /// it from milestone types, since [SingleShowupMilestone] also appears outside the
  /// tail zone (a same-outcome run of length 1).
  ///
  /// Thin wrapper over [groupWithStats] — kept as a separate method (rather than
  /// widening this return shape) because `(:milestones, :tailStartIndex)` record
  /// destructuring is used at several existing call sites and would break on a
  /// shape change (HAB-174 WU1.1).
  ({List<PactTimelineMilestone> milestones, int tailStartIndex}) group(
    List<Showup> showups, {
    DateTime? now,
  }) {
    final result = groupWithStats(showups, now: now);
    return (milestones: result.milestones, tailStartIndex: result.tailStartIndex);
  }

  /// Same grouping as [group], fused into one forward pass with the resolved-showup
  /// tallies ([PactStats] needs): [showupsDone], [showupsFailed], and [currentStreak]
  /// (the trailing run of consecutive `done` showups). This is what makes single-pass
  /// bundle computation possible in `PactDetailCache` — a forward "increment on done,
  /// reset on non-done" running counter's final value equals the reverse-scan trailing
  /// streak that [PactStats.compute] computes, for the same ascending-sorted,
  /// non-pending-excluded list (HAB-174 WU1.1).
  ///
  /// Single forward pass over [showups]: relies on the caller-supplied sort by
  /// [Showup.scheduledAt] (ascending) so the tail zone forms a contiguous suffix.
  /// Non-tail showups accumulate into same-outcome streaks that flush to a
  /// [ShowupStreakMilestone] (run ≥ 2) or [SingleShowupMilestone] (run of 1) on
  /// outcome change; tail showups are always emitted individually.
  ({
    List<PactTimelineMilestone> milestones,
    int tailStartIndex,
    int showupsDone,
    int showupsFailed,
    int currentStreak,
  }) groupWithStats(
    List<Showup> showups, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();

    final result = <PactTimelineMilestone>[];
    var tailStartIndex = -1;

    ShowupStatus? streakOutcome;
    var streakCount = 0;
    DateTime? streakFirstAt;
    DateTime? streakLastAt;
    String? streakLastShowupId;

    var showupsDone = 0;
    var showupsFailed = 0;
    var trailingStreak = 0;

    void flushStreak() {
      if (streakCount == 0) return;
      if (streakCount == 1) {
        result.add(SingleShowupMilestone(
          sortAt: streakFirstAt!,
          showupId: streakLastShowupId!,
          outcome: streakOutcome!,
          scheduledAt: streakFirstAt!,
        ));
      } else {
        result.add(ShowupStreakMilestone(
          sortAt: streakFirstAt!,
          outcome: streakOutcome!,
          count: streakCount,
          firstAt: streakFirstAt!,
          lastAt: streakLastAt!,
        ));
      }
      streakCount = 0;
      streakOutcome = null;
      streakFirstAt = null;
      streakLastAt = null;
      streakLastShowupId = null;
    }

    for (final showup in showups) {
      if (showup.status == ShowupStatus.pending) continue;

      if (showup.status == ShowupStatus.done) {
        showupsDone++;
        trailingStreak++;
      } else {
        showupsFailed++;
        trailingStreak = 0;
      }

      final inTail =
          TailZone.contains(scheduledAt: showup.scheduledAt, now: effectiveNow, days: noGroupingTailPeriodInDays);

      if (inTail) {
        flushStreak();
        if (tailStartIndex == -1) tailStartIndex = result.length;
        result.add(showup.note != null
            ? NotedShowupMilestone(
                sortAt: showup.scheduledAt,
                showupId: showup.id,
                scheduledAt: showup.scheduledAt,
                outcome: showup.status,
                note: showup.note!,
              )
            : SingleShowupMilestone(
                sortAt: showup.scheduledAt,
                showupId: showup.id,
                outcome: showup.status,
                scheduledAt: showup.scheduledAt,
              ));
        continue;
      }

      if (showup.note != null) {
        flushStreak();
        result.add(NotedShowupMilestone(
          sortAt: showup.scheduledAt,
          showupId: showup.id,
          scheduledAt: showup.scheduledAt,
          outcome: showup.status,
          note: showup.note!,
        ));
      } else {
        if (streakOutcome != null && streakOutcome != showup.status) {
          flushStreak();
        }
        streakOutcome = showup.status;
        streakCount++;
        streakFirstAt ??= showup.scheduledAt;
        streakLastAt = showup.scheduledAt;
        streakLastShowupId = showup.id;
      }
    }

    flushStreak();

    return (
      milestones: result,
      tailStartIndex: tailStartIndex == -1 ? result.length : tailStartIndex,
      showupsDone: showupsDone,
      showupsFailed: showupsFailed,
      currentStreak: trailingStreak,
    );
  }
}

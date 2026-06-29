import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/showup/tail_zone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

class PactTimelineGrouper {
  const PactTimelineGrouper({
    required this.groupingThreshold,
    this.noGroupingTailPeriodInDays = 7,
  });

  /// Minimum single-outcome run length to emit a streak item rather than a group item.
  final int groupingThreshold;

  /// Showups whose scheduledAt falls within this many days before [now] are
  /// always shown individually (tail zone). Defaults to 7.
  final int noGroupingTailPeriodInDays;

  /// Groups [showups] (oldest-first, may include pending) into timeline milestones.
  ///
  /// [now] anchors the tail-zone cutoff; defaults to [DateTime.now()].
  /// [tailStartIndex] in the result is the authoritative tail boundary — do not infer
  /// it from milestone types, since [SingleShowupMilestone] also appears in the
  /// non-tail zone when [groupingThreshold] == 1.
  ({List<PactTimelineMilestone> milestones, int tailStartIndex}) group(
    List<Showup> showups, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();

    final resolved = showups.where((s) => s.status != ShowupStatus.pending).toList();
    final nonTail = resolved
        .where(
            (s) => !TailZone.contains(scheduledAt: s.scheduledAt, now: effectiveNow, days: noGroupingTailPeriodInDays))
        .toList();
    final tail = resolved
        .where(
            (s) => TailZone.contains(scheduledAt: s.scheduledAt, now: effectiveNow, days: noGroupingTailPeriodInDays))
        .toList();

    final nonTailMilestones = _processNonTail(nonTail);
    final tailMilestones = _processTail(tail);
    return (
      milestones: [...nonTailMilestones, ...tailMilestones],
      tailStartIndex: nonTailMilestones.length,
    );
  }

  List<PactTimelineMilestone> _processNonTail(List<Showup> showups) {
    final threshold = groupingThreshold;
    final result = <PactTimelineMilestone>[];

    var groupDone = 0;
    var groupFailed = 0;
    DateTime? groupFirstAt;
    DateTime? groupLastAt;

    ShowupStatus? streakOutcome;
    var streakCount = 0;
    DateTime? streakFirstAt;
    DateTime? streakLastAt;
    String? streakLastShowupId;

    void flushStreak() {
      if (streakCount == 0) return;
      final groupTotal = groupDone + groupFailed;
      if (groupTotal > 0 && groupTotal + streakCount >= threshold) {
        result.add(ShowupGroupMilestone(
          sortAt: groupFirstAt!,
          total: groupTotal,
          doneCount: groupDone,
          failedCount: groupFailed,
          firstAt: groupFirstAt!,
          lastAt: groupLastAt!,
        ));
        groupDone = 0;
        groupFailed = 0;
        groupFirstAt = null;
        groupLastAt = null;
        if (streakCount >= threshold) {
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
        } else {
          if (streakOutcome == ShowupStatus.done) {
            groupDone = streakCount;
          } else {
            groupFailed = streakCount;
          }
          groupFirstAt = streakFirstAt;
          groupLastAt = streakLastAt;
        }
      } else if (groupTotal == 0 && streakCount >= threshold) {
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
      } else {
        if (streakOutcome == ShowupStatus.done) {
          groupDone += streakCount;
        } else {
          groupFailed += streakCount;
        }
        groupFirstAt ??= streakFirstAt;
        groupLastAt = streakLastAt;
      }
      streakCount = 0;
      streakOutcome = null;
      streakFirstAt = null;
      streakLastAt = null;
      streakLastShowupId = null;
    }

    void flushGroup() {
      final groupTotal = groupDone + groupFailed;
      if (groupTotal == 0) return;
      result.add(ShowupGroupMilestone(
        sortAt: groupFirstAt!,
        total: groupTotal,
        doneCount: groupDone,
        failedCount: groupFailed,
        firstAt: groupFirstAt!,
        lastAt: groupLastAt!,
      ));
      groupDone = 0;
      groupFailed = 0;
      groupFirstAt = null;
      groupLastAt = null;
    }

    for (final showup in showups) {
      if (showup.note != null) {
        flushStreak();
        flushGroup();
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
    flushGroup();
    return result;
  }

  List<PactTimelineMilestone> _processTail(List<Showup> tail) => tail.map((showup) {
        if (showup.note != null) {
          return NotedShowupMilestone(
            sortAt: showup.scheduledAt,
            showupId: showup.id,
            scheduledAt: showup.scheduledAt,
            outcome: showup.status,
            note: showup.note!,
          );
        }
        return SingleShowupMilestone(
          sortAt: showup.scheduledAt,
          showupId: showup.id,
          outcome: showup.status,
          scheduledAt: showup.scheduledAt,
        );
      }).toList();
}

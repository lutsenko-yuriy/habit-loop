import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

class PactTimelineGrouper {
  const PactTimelineGrouper({
    required this.groupingThreshold,
    int? noGroupingTailSize,
  }) : noGroupingTailSize = noGroupingTailSize ?? groupingThreshold;

  /// Minimum single-outcome run length to emit a streak item rather than a group item.
  final int groupingThreshold;

  /// Number of most-recent showups always shown individually. Defaults to [groupingThreshold].
  final int noGroupingTailSize;

  /// Groups [showups] (oldest-first, may include pending) into timeline milestones.
  List<PactTimelineMilestone> group(List<Showup> showups) {
    final resolved = showups.where((s) => s.status != ShowupStatus.pending).toList();
    final tailStart = (resolved.length - noGroupingTailSize).clamp(0, resolved.length);

    final nonTail = resolved.sublist(0, tailStart);
    final tail = resolved.sublist(tailStart);

    return [
      ..._processNonTail(nonTail),
      ..._processTail(tail),
    ];
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
          result.add(ShowupStreakMilestone(
            sortAt: streakFirstAt!,
            outcome: streakOutcome!,
            count: streakCount,
            firstAt: streakFirstAt!,
            lastAt: streakLastAt!,
          ));
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
        result.add(ShowupStreakMilestone(
          sortAt: streakFirstAt!,
          outcome: streakOutcome!,
          count: streakCount,
          firstAt: streakFirstAt!,
          lastAt: streakLastAt!,
        ));
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

import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

sealed class PactTimelineMilestone {
  const PactTimelineMilestone({required this.sortAt});
  final DateTime sortAt;
}

final class PactCreatedMilestone extends PactTimelineMilestone {
  const PactCreatedMilestone({
    required super.sortAt,
    required this.habitName,
    required this.schedule,
    required this.plannedEndDate,
  });

  final String habitName;
  final ShowupSchedule schedule;
  final DateTime plannedEndDate;
}

final class ShowupStreakMilestone extends PactTimelineMilestone {
  const ShowupStreakMilestone({
    required super.sortAt,
    required this.outcome,
    required this.count,
    required this.firstAt,
    required this.lastAt,
  });

  final ShowupStatus outcome;
  final int count;
  final DateTime firstAt;
  final DateTime lastAt;
}

final class SingleShowupMilestone extends PactTimelineMilestone {
  const SingleShowupMilestone({
    required super.sortAt,
    required this.showupId,
    required this.outcome,
    required this.scheduledAt,
  });

  final String showupId;
  final ShowupStatus outcome;
  final DateTime scheduledAt;
}

final class NotedShowupMilestone extends PactTimelineMilestone {
  const NotedShowupMilestone({
    required super.sortAt,
    required this.showupId,
    required this.scheduledAt,
    required this.outcome,
    required this.note,
  });

  final String showupId;
  final DateTime scheduledAt;
  final ShowupStatus outcome;
  final String note;
}

/// A run of consecutive showups covered by the same [PactBreak] (HAB-216) — merged
/// into a single, non-tappable timeline entry regardless of outcome (including
/// explicit `done`/`failed` marks inside the break window) or tail-zone boundary.
/// [firstAt]/[lastAt] are the covered-showup range, not [pactBreak]'s own
/// startDate/effectiveEnd — a break can start before its first showup and extend
/// into the future, and future days must stay invisible (existing rule).
final class BreakMilestone extends PactTimelineMilestone {
  const BreakMilestone({
    required super.sortAt,
    required this.pactBreak,
    required this.firstAt,
    required this.lastAt,
    required this.count,
  });

  final PactBreak pactBreak;
  final DateTime firstAt;
  final DateTime lastAt;
  final int count;
}

final class CurrentStateMilestone extends PactTimelineMilestone {
  const CurrentStateMilestone({
    required super.sortAt,
    required this.showupsRemaining,
    required this.plannedEndDate,
    this.nextScheduledAt,
  });

  /// Earliest pending showup date; may be in the past when the user has overdue pending showups.
  /// The UI is responsible for distinguishing "upcoming" vs "overdue" when rendering this.
  final DateTime? nextScheduledAt;
  final int showupsRemaining;
  final DateTime plannedEndDate;
}

final class PactConcludedMilestone extends PactTimelineMilestone {
  const PactConcludedMilestone({
    required super.sortAt,
    required this.concludedAt,
    required this.finalStatus,
    this.note,
  });

  final DateTime concludedAt;
  final PactStatus finalStatus;
  final String? note;
}

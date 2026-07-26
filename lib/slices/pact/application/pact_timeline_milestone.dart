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

/// A pact break's own timeline entry — one per [PactBreak], sorted by its
/// [startDate] (HAB-195 WU5.1). Distinct from the individual pending showups
/// that fall inside the break window, which stay invisible on the timeline
/// exactly like any other pending showup.
final class PactBreakMilestone extends PactTimelineMilestone {
  const PactBreakMilestone({
    required super.sortAt,
    required this.rationale,
    required this.startDate,
    this.plannedEndDate,
    this.stoppedAt,
  });

  final String rationale;
  final DateTime startDate;

  /// null = "until pact ends".
  final DateTime? plannedEndDate;

  /// null = not stopped (still active or scheduled).
  final DateTime? stoppedAt;
}

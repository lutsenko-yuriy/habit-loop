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

final class ShowupGroupMilestone extends PactTimelineMilestone {
  const ShowupGroupMilestone({
    required super.sortAt,
    required this.total,
    required this.doneCount,
    required this.failedCount,
    required this.firstAt,
    required this.lastAt,
  });

  final int total;
  final int doneCount;
  final int failedCount;
  final DateTime firstAt;
  final DateTime lastAt;
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

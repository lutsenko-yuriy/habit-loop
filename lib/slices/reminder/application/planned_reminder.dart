import 'package:flutter/foundation.dart';
import 'package:habit_loop/domain/showup/showup.dart';

/// One showup's desired notification set, as computed by [ReminderPlanner]
/// (HAB-254 WU1) — pure data, carrying enough (title/body/offset per
/// notification kind) for both immediate scheduling
/// (ReminderSchedulingService) and future desired-vs-actual diffing
/// (NotificationReconciliationService, HAB-254 WU2).
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.showup,
    required this.reminderTitle,
    required this.reminderBody,
    required this.includeDeadline,
    this.deadlineTitle,
    this.deadlineBody,
    required this.includeHurryUp,
    this.hurryUpOffset,
    this.hurryUpTitle,
    this.hurryUpBody,
  });

  final Showup showup;
  final String reminderTitle;
  final String reminderBody;
  final bool includeDeadline;
  final String? deadlineTitle;
  final String? deadlineBody;
  final bool includeHurryUp;
  final Duration? hurryUpOffset;
  final String? hurryUpTitle;
  final String? hurryUpBody;
}

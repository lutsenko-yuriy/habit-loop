import 'package:flutter/foundation.dart';
import 'package:habit_loop/domain/showup/showup.dart';

/// One showup's desired notification set, as computed by [ReminderPlanner]
/// (HAB-254 WU1) — pure data, carrying enough (title/body/offset per
/// notification kind) for both immediate scheduling
/// (ReminderSchedulingService) and future desired-vs-actual diffing
/// (NotificationReconciliationService, HAB-254 WU2).
///
/// [deadline]/[hurryUp] are nullable records rather than parallel
/// `includeX`+nullable-field groups — `null` *is* "not included", so there is
/// no separate invariant to keep in sync (review/audit findings, PR #410).
/// Value equality (rather than identity) matters for WU2's diff, where two
/// plans need to compare as equal when their content matches.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.showup,
    required this.reminderTitle,
    required this.reminderBody,
    this.deadline,
    this.hurryUp,
  });

  final Showup showup;
  final String reminderTitle;
  final String reminderBody;
  final ({String title, String body})? deadline;
  final ({Duration offset, String title, String body})? hurryUp;

  bool get includeDeadline => deadline != null;
  bool get includeHurryUp => hurryUp != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedReminder &&
          runtimeType == other.runtimeType &&
          showup == other.showup &&
          reminderTitle == other.reminderTitle &&
          reminderBody == other.reminderBody &&
          deadline == other.deadline &&
          hurryUp == other.hurryUp;

  @override
  int get hashCode => Object.hash(showup, reminderTitle, reminderBody, deadline, hurryUp);
}

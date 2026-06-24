import 'package:flutter/widgets.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

/// Returns the headline text for a timeline milestone.
String milestoneTitle(AppLocalizations l10n, PactTimelineMilestone milestone) => switch (milestone) {
      PactCreatedMilestone _ => l10n.timelinePactCreated,
      ShowupStreakMilestone m =>
        m.outcome == ShowupStatus.done ? l10n.timelineDoneInARow(m.count) : l10n.timelineMissedInARow(m.count),
      SingleShowupMilestone m => switch (m.outcome) {
          ShowupStatus.done => l10n.showupDone,
          ShowupStatus.failed => l10n.showupFailed,
          ShowupStatus.pending => l10n.showupPending,
        },
      ShowupGroupMilestone m => l10n.timelineGroup(m.total, m.doneCount, m.failedCount),
      NotedShowupMilestone m => m.outcome == ShowupStatus.done ? l10n.showupDone : l10n.showupFailed,
      CurrentStateMilestone _ => l10n.timelineCurrentState,
      PactConcludedMilestone m =>
        m.finalStatus == PactStatus.completed ? l10n.timelinePactConcludedCompleted : l10n.timelinePactConcludedStopped,
    };

/// Returns a locale-aware date range string for milestones that span a range.
///
/// For [ShowupStreakMilestone] and [ShowupGroupMilestone]: "Jan 1 – Jan 10, 2024".
/// Returns `null` for milestones where a date range does not apply.
String? milestoneDateRange(BuildContext context, PactTimelineMilestone milestone) {
  DateTime? first;
  DateTime? last;

  if (milestone is ShowupStreakMilestone) {
    first = milestone.firstAt;
    last = milestone.lastAt;
  } else if (milestone is ShowupGroupMilestone) {
    first = milestone.firstAt;
    last = milestone.lastAt;
  } else {
    return null;
  }

  final firstStr = formatLocaleDate(first);
  final lastStr = formatLocaleDate(last);
  return first == last ? firstStr : '$firstStr – $lastStr';
}

import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

/// All computed timeline milestones for a single pact.
///
/// [anchorStart] and [anchorEnd] are always present outside the grouping window.
/// [milestones] contains all grouped showup milestones, oldest-first.
final class PactTimelinePage {
  const PactTimelinePage({
    required this.anchorStart,
    required this.anchorEnd,
    required this.milestones,
    required this.tailPeriodInDays,
    required this.tailStartIndex,
  });

  final PactCreatedMilestone anchorStart;

  /// [CurrentStateMilestone] for active pacts; [PactConcludedMilestone] for concluded ones.
  final PactTimelineMilestone anchorEnd;

  final List<PactTimelineMilestone> milestones;

  /// Value of `pact_timeline_no_grouping_tail_period_in_days` used when building this page.
  final int tailPeriodInDays;

  /// Index of the first tail-zone milestone in [milestones] (i.e. the count of non-tail
  /// milestones). The section header must be placed at this index — do not infer it by
  /// searching for [SingleShowupMilestone], which also appears in the non-tail zone.
  final int tailStartIndex;
}

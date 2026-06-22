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
  });

  final PactCreatedMilestone anchorStart;

  /// [CurrentStateMilestone] for active pacts; [PactConcludedMilestone] for concluded ones.
  final PactTimelineMilestone anchorEnd;

  final List<PactTimelineMilestone> milestones;
}

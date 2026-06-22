import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

/// One page of computed timeline milestones for a single pact.
///
/// [anchorStart] and [anchorEnd] are always present regardless of pagination.
/// [milestones] is the paginated middle section (oldest-first).
final class PactTimelinePage {
  const PactTimelinePage({
    required this.anchorStart,
    required this.anchorEnd,
    required this.milestones,
    required this.hasMoreOlder,
    required this.loadedPageCount,
  });

  final PactCreatedMilestone anchorStart;

  /// [CurrentStateMilestone] for active pacts; [PactConcludedMilestone] for concluded ones.
  final PactTimelineMilestone anchorEnd;

  final List<PactTimelineMilestone> milestones;
  final bool hasMoreOlder;
  final int loadedPageCount;
}

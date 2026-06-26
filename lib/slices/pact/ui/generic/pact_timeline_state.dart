import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

class PactTimelineState {
  const PactTimelineState({
    this.anchorStart,
    this.anchorEnd,
    this.milestones = const [],
    this.tailPeriodInDays = 7,
    this.tailStartIndex = 0,
    this.isLoading = true,
    this.loadError,
  });

  final PactCreatedMilestone? anchorStart;

  /// [CurrentStateMilestone] for active pacts; [PactConcludedMilestone] for concluded ones.
  final PactTimelineMilestone? anchorEnd;

  final List<PactTimelineMilestone> milestones;

  /// Value of `pact_timeline_no_grouping_tail_period_in_days` at load time — used in the section header.
  final int tailPeriodInDays;

  /// Index of the first tail-zone milestone in [milestones]. The UI places the
  /// section header here; do not infer this from milestone types.
  final int tailStartIndex;

  final bool isLoading;
  final Object? loadError;

  PactTimelineState copyWith({
    PactCreatedMilestone? anchorStart,
    PactTimelineMilestone? anchorEnd,
    List<PactTimelineMilestone>? milestones,
    int? tailPeriodInDays,
    int? tailStartIndex,
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
  }) {
    return PactTimelineState(
      anchorStart: anchorStart ?? this.anchorStart,
      anchorEnd: anchorEnd ?? this.anchorEnd,
      milestones: milestones ?? this.milestones,
      tailPeriodInDays: tailPeriodInDays ?? this.tailPeriodInDays,
      tailStartIndex: tailStartIndex ?? this.tailStartIndex,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}

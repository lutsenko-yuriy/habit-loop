import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

class PactTimelineState {
  const PactTimelineState({
    this.anchorStart,
    this.anchorEnd,
    this.milestones = const [],
    this.isLoading = true,
    this.loadError,
  });

  final PactCreatedMilestone? anchorStart;

  /// [CurrentStateMilestone] for active pacts; [PactConcludedMilestone] for concluded ones.
  final PactTimelineMilestone? anchorEnd;

  final List<PactTimelineMilestone> milestones;

  final bool isLoading;
  final Object? loadError;

  PactTimelineState copyWith({
    PactCreatedMilestone? anchorStart,
    PactTimelineMilestone? anchorEnd,
    List<PactTimelineMilestone>? milestones,
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
  }) {
    return PactTimelineState(
      anchorStart: anchorStart ?? this.anchorStart,
      anchorEnd: anchorEnd ?? this.anchorEnd,
      milestones: milestones ?? this.milestones,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}

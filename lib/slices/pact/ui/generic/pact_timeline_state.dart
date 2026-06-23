import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

class PactTimelineState {
  const PactTimelineState({
    this.anchorStart,
    this.anchorEnd,
    this.visibleMilestones = const [],
    this.totalMilestoneCount = 0,
    this.hasMoreOlder = false,
    this.loadedPageCount = 0,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.loadError,
  });

  final PactCreatedMilestone? anchorStart;

  /// [CurrentStateMilestone] for active pacts; [PactConcludedMilestone] for concluded ones.
  final PactTimelineMilestone? anchorEnd;

  /// Windowed subset of all milestones, oldest-first. Starts at the most recent
  /// [_kFirstPageSize] items; "load more" prepends older items in [_kNthPageSize]
  /// increments until the full history is visible.
  final List<PactTimelineMilestone> visibleMilestones;

  /// Length of the full (unwindowed) milestone list. Used to compute [hasMoreOlder].
  final int totalMilestoneCount;

  final bool hasMoreOlder;

  /// Number of display pages loaded so far (1 after initial load, incremented by [loadMoreOlder]).
  final int loadedPageCount;

  final bool isLoading;
  final bool isLoadingMore;
  final Object? loadError;

  PactTimelineState copyWith({
    PactCreatedMilestone? anchorStart,
    PactTimelineMilestone? anchorEnd,
    List<PactTimelineMilestone>? visibleMilestones,
    int? totalMilestoneCount,
    bool? hasMoreOlder,
    int? loadedPageCount,
    bool? isLoading,
    bool? isLoadingMore,
    Object? loadError,
    bool clearLoadError = false,
  }) {
    return PactTimelineState(
      anchorStart: anchorStart ?? this.anchorStart,
      anchorEnd: anchorEnd ?? this.anchorEnd,
      visibleMilestones: visibleMilestones ?? this.visibleMilestones,
      totalMilestoneCount: totalMilestoneCount ?? this.totalMilestoneCount,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      loadedPageCount: loadedPageCount ?? this.loadedPageCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}

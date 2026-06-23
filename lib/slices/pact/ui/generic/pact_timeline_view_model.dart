import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_timeline_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';

// Number of milestones shown on the initial load (most recent N).
const int _kFirstPageSize = 20;

// Number of older milestones prepended per "load more" tap.
const int _kNthPageSize = 10;

// Overridable in tests to make CurrentStateMilestone.sortAt deterministic.
final pactTimelineNowProvider = Provider<DateTime>((ref) => DateTime.now());

final pactTimelineViewModelProvider = NotifierProviderFamily<PactTimelineViewModel, PactTimelineState, String>(
  PactTimelineViewModel.new,
);

class PactTimelineViewModel extends FamilyNotifier<PactTimelineState, String> {
  @override
  PactTimelineState build(String pactId) => const PactTimelineState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearLoadError: true);
    try {
      unawaited(ref.read(crashlyticsServiceProvider).log('screen: pact_timeline(id=$arg)'));

      // Evict stale cache so re-entry always fetches fresh showup data from DB.
      ref.read(pactTimelineCacheProvider).evict(arg);

      final now = ref.read(pactTimelineNowProvider);
      final page = await ref.read(pactTimelineServiceProvider).loadAll(pactId: arg, now: now);

      final all = page.milestones;
      final visible = _window(all, _kFirstPageSize);

      state = state.copyWith(
        anchorStart: page.anchorStart,
        anchorEnd: page.anchorEnd,
        visibleMilestones: visible,
        totalMilestoneCount: all.length,
        hasMoreOlder: all.length > _kFirstPageSize,
        loadedPageCount: 1,
        isLoading: false,
      );
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('pact_timeline_load_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  Future<void> loadMoreOlder() async {
    if (!state.hasMoreOlder || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final now = ref.read(pactTimelineNowProvider);
      // Cache hit — no DB round-trip.
      final page = await ref.read(pactTimelineServiceProvider).loadAll(pactId: arg, now: now);

      final all = page.milestones;
      final targetCount = state.visibleMilestones.length + _kNthPageSize;
      final visible = _window(all, targetCount);
      final newPageCount = state.loadedPageCount + 1;

      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
              PactTimelineLoadMoreEvent(pactId: arg, pageNumber: newPageCount),
            ),
      );

      state = state.copyWith(
        visibleMilestones: visible,
        hasMoreOlder: visible.length < all.length,
        loadedPageCount: newPageCount,
        isLoadingMore: false,
      );
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('pact_timeline_load_more_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void onMilestoneTapped(PactTimelineMilestone milestone) {
    final itemType = milestone is NotedShowupMilestone ? 'noted_showup' : 'single_showup';
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            PactTimelineMilestoneTappedEvent(pactId: arg, itemType: itemType),
          ),
    );
  }

  /// Returns the milestones from the end of [all], oldest-first.
  ///
  /// [count] is clamped to [all.length], so the returned list is never longer
  /// than the full list and never contains duplicates of the anchor nodes.
  List<PactTimelineMilestone> _window(List<PactTimelineMilestone> all, int count) {
    if (all.length <= count) return List.of(all);
    return List.of(all.sublist(all.length - count));
  }
}

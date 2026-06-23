import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_timeline_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';

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

      state = state.copyWith(
        anchorStart: page.anchorStart,
        anchorEnd: page.anchorEnd,
        milestones: page.milestones,
        isLoading: false,
      );
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('pact_timeline_load_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  void onMilestoneTapped(PactTimelineMilestone milestone) {
    assert(milestone is NotedShowupMilestone || milestone is SingleShowupMilestone);
    final itemType = milestone is NotedShowupMilestone ? 'noted_showup' : 'single_showup';
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            PactTimelineMilestoneTappedEvent(pactId: arg, itemType: itemType),
          ),
    );
  }
}

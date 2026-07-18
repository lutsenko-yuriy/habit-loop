import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_timeline_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_page.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_state.dart';

// Overridable in tests to make CurrentStateMilestone.sortAt deterministic.
final pactTimelineNowProvider = Provider<DateTime>((ref) => DateTime.now());

final pactTimelineViewModelProvider = NotifierProviderFamily<PactTimelineViewModel, PactTimelineState, String>(
  PactTimelineViewModel.new,
);

class PactTimelineViewModel extends FamilyNotifier<PactTimelineState, String> {
  @override
  PactTimelineState build(String pactId) {
    // Seeds from the shared cache's warm bundle if one is already present —
    // the only real navigation path (Pact Details → Timeline) always warms it
    // first, so this makes the AppBar title correct on the very first frame
    // without a forwarded initialHabitName argument (HAB-173 workaround,
    // removed HAB-174 WU3).
    final page = ref.read(pactDetailCacheProvider).peek(pactId)?.timelinePage;
    if (page == null) return const PactTimelineState();
    return _stateFromPage(const PactTimelineState(), page);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearLoadError: true);
    try {
      unawaited(ref.read(crashlyticsServiceProvider).log('screen: pact_timeline(id=$arg)'));

      final now = ref.read(pactTimelineNowProvider);
      final bundle = await ref.read(pactDetailCacheProvider).load(arg, now: now);
      final page = bundle.timelinePage;

      state = _stateFromPage(state, page).copyWith(isLoading: false);

      final pactStatus = switch (page.anchorEnd) {
        CurrentStateMilestone _ => 'active',
        PactConcludedMilestone m when m.finalStatus == PactStatus.completed => 'completed',
        PactConcludedMilestone _ => 'stopped',
        _ => 'unknown',
      };
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
              PactTimelineOpenedEvent(
                pactId: arg,
                pactStatus: pactStatus,
                milestoneCount: page.milestones.length,
              ),
            ),
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

PactTimelineState _stateFromPage(PactTimelineState state, PactTimelinePage page) => state.copyWith(
      anchorStart: page.anchorStart,
      anchorEnd: page.anchorEnd,
      milestones: page.milestones,
      tailPeriodInDays: page.tailPeriodInDays,
      tailStartIndex: page.tailStartIndex,
    );

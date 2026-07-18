import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_timeline_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_view_model.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';

const _pactId = 'p1';
final _now = DateTime(2024, 2, 15, 12, 0);

Pact _pact({PactStatus status = PactStatus.active}) => Pact(
      id: _pactId,
      habitName: 'Meditate',
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 3, 31),
      showupDuration: const Duration(minutes: 30),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: status,
    );

Showup _showup(String id, DateTime at, {ShowupStatus status = ShowupStatus.done, String? note}) => Showup(
      id: id,
      pactId: _pactId,
      scheduledAt: at,
      duration: const Duration(minutes: 30),
      status: status,
      note: note,
    );

({ProviderContainer container, FakeAnalyticsService analytics, PactDetailCache cache}) _makeContainer({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
  PactTimelineGrouper grouper = const PactTimelineGrouper(),
}) {
  final analytics = FakeAnalyticsService();
  final pactRepo = InMemoryPactRepository(pacts);
  final showupRepo = InMemoryShowupRepository(showups);
  final cache = PactDetailCache(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    grouper: grouper,
  );
  final container = ProviderContainer(
    overrides: [
      pactDetailCacheProvider.overrideWithValue(cache),
      analyticsServiceProvider.overrideWithValue(analytics),
      pactTimelineNowProvider.overrideWithValue(_now),
    ],
  );
  return (container: container, analytics: analytics, cache: cache);
}

void main() {
  group('PactTimelineViewModel — initial state', () {
    test('starts loading with no data when the cache is cold', () {
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()]);
      addTearDown(container.dispose);
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.isLoading, true);
      expect(state.anchorStart, isNull);
      expect(state.anchorEnd, isNull);
      expect(state.milestones, isEmpty);
    });

    test('seeds anchors and milestones from an already-warm cache entry', () async {
      final showups = [_showup('s1', DateTime(2024, 1, 5, 8))];
      final (:container, analytics: _, :cache) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);

      // Mirrors production: Pact Details warms the shared cache before
      // Timeline is ever pushed, so build() should see it via peek().
      await cache.load(_pactId, now: _now);

      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.anchorStart, isA<PactCreatedMilestone>());
      expect(state.milestones, hasLength(1));
      // Still isLoading — the screen's initState still runs a real load().
      expect(state.isLoading, true);
    });
  });

  group('PactTimelineViewModel — load', () {
    test('populates anchors and all milestones', () async {
      final showups = [_showup('s1', DateTime(2024, 1, 5, 8))];
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.isLoading, false);
      expect(state.anchorStart, isA<PactCreatedMilestone>());
      expect(state.anchorEnd, isA<CurrentStateMilestone>());
      expect(state.milestones, hasLength(1));
    });

    test('milestones are oldest-first', () async {
      final showups = List.generate(5, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      final sortAts = container.read(pactTimelineViewModelProvider(_pactId)).milestones.map((m) => m.sortAt).toList();
      expect(sortAts, equals([...sortAts]..sort()));
    });

    test('reuses an already-warm cache entry instead of re-fetching from DB', () async {
      final pact = _pact();
      final showupRepo = _CountingShowupRepository([_showup('fresh', DateTime(2024, 1, 5, 8))]);
      final pactRepo = InMemoryPactRepository([pact]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(),
      );
      final container = ProviderContainer(
        overrides: [
          pactDetailCacheProvider.overrideWithValue(cache),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          pactTimelineNowProvider.overrideWithValue(_now),
        ],
      );
      addTearDown(container.dispose);

      // Warm the cache the way Pact Details does on first open this session.
      await cache.load(_pactId, now: _now);
      final callsAfterWarm = showupRepo.getShowupsForPactCallCount;

      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();

      expect(
        showupRepo.getShowupsForPactCallCount,
        callsAfterWarm,
        reason: 'Timeline load() must reuse the already-warm PactDetailCache entry, not re-fetch from DB',
      );
      expect(container.read(pactTimelineViewModelProvider(_pactId)).milestones, hasLength(1));
    });

    test('sets loadError when pact is not found', () async {
      final (:container, analytics: _, cache: _) = _makeContainer();
      addTearDown(container.dispose);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.isLoading, false);
      expect(state.loadError, isNotNull);
    });

    test('anchorEnd is PactConcludedMilestone for concluded pact', () async {
      final (:container, analytics: _, cache: _) = _makeContainer(
        pacts: [_pact(status: PactStatus.completed)],
      );
      addTearDown(container.dispose);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      expect(container.read(pactTimelineViewModelProvider(_pactId)).anchorEnd, isA<PactConcludedMilestone>());
    });
  });

  group('PactTimelineViewModel — onMilestoneTapped', () {
    test('fires noted_showup event for NotedShowupMilestone', () async {
      final showup = _showup('noted', DateTime(2024, 1, 5, 8), note: 'Great session');
      final (:container, :analytics, cache: _) = _makeContainer(pacts: [_pact()], showups: [showup]);
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      final noted =
          container.read(pactTimelineViewModelProvider(_pactId)).milestones.whereType<NotedShowupMilestone>().first;
      notifier.onMilestoneTapped(noted);
      final event = analytics.loggedEvents.whereType<PactTimelineMilestoneTappedEvent>().single;
      expect(event.pactId, _pactId);
      expect(event.itemType, 'noted_showup');
    });

    test('fires single_showup event for SingleShowupMilestone', () async {
      // tailPeriodInDays=45 puts all Jan 1-12 showups in the tail (within 45 days of Feb 15).
      final showups = List.generate(12, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final (:container, :analytics, cache: _) = _makeContainer(
        pacts: [_pact()],
        showups: showups,
        grouper: const PactTimelineGrouper(noGroupingTailPeriodInDays: 45),
      );
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      final single =
          container.read(pactTimelineViewModelProvider(_pactId)).milestones.whereType<SingleShowupMilestone>().first;
      notifier.onMilestoneTapped(single);
      final event = analytics.loggedEvents.whereType<PactTimelineMilestoneTappedEvent>().single;
      expect(event.pactId, _pactId);
      expect(event.itemType, 'single_showup');
    });
  });
}

class _CountingShowupRepository extends InMemoryShowupRepository {
  _CountingShowupRepository([super.initialShowups]);

  int getShowupsForPactCallCount = 0;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    getShowupsForPactCallCount++;
    return super.getShowupsForPact(pactId);
  }
}

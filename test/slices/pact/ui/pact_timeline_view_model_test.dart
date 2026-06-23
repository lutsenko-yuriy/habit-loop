import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_timeline_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_service.dart';
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

({ProviderContainer container, FakeAnalyticsService analytics, PactTimelineCache cache}) _makeContainer({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
  PactTimelineGrouper grouper = const PactTimelineGrouper(groupingThreshold: 10),
}) {
  final analytics = FakeAnalyticsService();
  final cache = PactTimelineCache();
  final pactRepo = InMemoryPactRepository(pacts);
  final showupRepo = InMemoryShowupRepository(showups);
  final service = PactTimelineService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    grouper: grouper,
    cache: cache,
  );
  final container = ProviderContainer(
    overrides: [
      pactTimelineServiceProvider.overrideWithValue(service),
      pactTimelineCacheProvider.overrideWithValue(cache),
      analyticsServiceProvider.overrideWithValue(analytics),
      pactTimelineNowProvider.overrideWithValue(_now),
    ],
  );
  return (container: container, analytics: analytics, cache: cache);
}

void main() {
  group('PactTimelineViewModel — initial state', () {
    test('starts loading with no data', () {
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()]);
      addTearDown(container.dispose);
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.isLoading, true);
      expect(state.anchorStart, isNull);
      expect(state.anchorEnd, isNull);
      expect(state.visibleMilestones, isEmpty);
    });
  });

  group('PactTimelineViewModel — load', () {
    test('populates anchors and clears isLoading', () async {
      final (:container, analytics: _, cache: _) = _makeContainer(
        pacts: [_pact()],
        showups: [_showup('s1', DateTime(2024, 1, 5, 8))],
      );
      addTearDown(container.dispose);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.isLoading, false);
      expect(state.anchorStart, isA<PactCreatedMilestone>());
      expect(state.anchorEnd, isA<CurrentStateMilestone>());
    });

    test('shows all milestones when count ≤ first-page size', () async {
      final showups = List.generate(5, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.visibleMilestones, hasLength(5));
      expect(state.hasMoreOlder, false);
    });

    test('windows to most recent 20 when count > first-page size', () async {
      // Noted showups each produce 1 NotedShowupMilestone → 25 milestones total.
      final showups = List.generate(25, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8), note: 'n'));
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.visibleMilestones, hasLength(20));
      expect(state.totalMilestoneCount, 25);
      expect(state.hasMoreOlder, true);
      expect(state.loadedPageCount, 1);
    });

    test('visible milestones are oldest-first', () async {
      final showups = List.generate(5, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      final sortAts = state.visibleMilestones.map((m) => m.sortAt).toList();
      expect(sortAts, equals([...sortAts]..sort()));
    });

    test('evicts stale cache before loading so fresh DB data is used', () async {
      final (:container, analytics: _, :cache) = _makeContainer(
        pacts: [_pact()],
        showups: [_showup('fresh', DateTime(2024, 1, 5, 8))],
      );
      addTearDown(container.dispose);
      // Seed the cache with 3 stale entries to verify they are evicted.
      cache.populate(_pactId, [
        _showup('stale1', DateTime(2024, 1, 1, 8)),
        _showup('stale2', DateTime(2024, 1, 2, 8)),
        _showup('stale3', DateTime(2024, 1, 3, 8)),
      ]);
      await container.read(pactTimelineViewModelProvider(_pactId).notifier).load();
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      // Stale 3-item cache was evicted; DB has 1 showup → 1 milestone.
      expect(state.visibleMilestones, hasLength(1));
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
      final state = container.read(pactTimelineViewModelProvider(_pactId));
      expect(state.anchorEnd, isA<PactConcludedMilestone>());
    });
  });

  group('PactTimelineViewModel — loadMoreOlder', () {
    test('no-op when hasMoreOlder is false', () async {
      final showups = List.generate(5, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      expect(container.read(pactTimelineViewModelProvider(_pactId)).hasMoreOlder, false);
      await notifier.loadMoreOlder();
      expect(container.read(pactTimelineViewModelProvider(_pactId)).loadedPageCount, 1);
    });

    test('expands visible milestones by nthPageSize', () async {
      final showups = List.generate(25, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8), note: 'n'));
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      expect(container.read(pactTimelineViewModelProvider(_pactId)).visibleMilestones, hasLength(20));
      await notifier.loadMoreOlder();
      // 25 total, 20 → 25 (only 5 older remain, nthPageSize=10 clamped by list length).
      expect(container.read(pactTimelineViewModelProvider(_pactId)).visibleMilestones, hasLength(25));
    });

    test('fires PactTimelineLoadMoreEvent with incremented pageNumber', () async {
      final showups = List.generate(35, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8), note: 'n'));
      final (:container, :analytics, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      await notifier.loadMoreOlder();
      final event = analytics.loggedEvents.whereType<PactTimelineLoadMoreEvent>().single;
      expect(event.pactId, _pactId);
      expect(event.pageNumber, 2);
    });

    test('sets hasMoreOlder=false when all milestones become visible', () async {
      final showups = List.generate(25, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8), note: 'n'));
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      await notifier.loadMoreOlder();
      expect(container.read(pactTimelineViewModelProvider(_pactId)).hasMoreOlder, false);
    });

    test('increments loadedPageCount on each call', () async {
      final showups = List.generate(45, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8), note: 'n'));
      final (:container, analytics: _, cache: _) = _makeContainer(pacts: [_pact()], showups: showups);
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      await notifier.loadMoreOlder();
      await notifier.loadMoreOlder();
      expect(container.read(pactTimelineViewModelProvider(_pactId)).loadedPageCount, 3);
    });
  });

  group('PactTimelineViewModel — onMilestoneTapped', () {
    test('fires noted_showup event for NotedShowupMilestone', () async {
      final showup = _showup('noted', DateTime(2024, 1, 5, 8), note: 'Great session');
      final (:container, :analytics, cache: _) = _makeContainer(pacts: [_pact()], showups: [showup]);
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      final noted = container
          .read(pactTimelineViewModelProvider(_pactId))
          .visibleMilestones
          .whereType<NotedShowupMilestone>()
          .first;
      notifier.onMilestoneTapped(noted);
      final event = analytics.loggedEvents.whereType<PactTimelineMilestoneTappedEvent>().single;
      expect(event.pactId, _pactId);
      expect(event.itemType, 'noted_showup');
    });

    test('fires single_showup event for SingleShowupMilestone', () async {
      // threshold=10, tail=3 → last 3 showups become SingleShowupMilestones.
      final showups = List.generate(12, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final (:container, :analytics, cache: _) = _makeContainer(
        pacts: [_pact()],
        showups: showups,
        grouper: const PactTimelineGrouper(groupingThreshold: 10, noGroupingTailSize: 3),
      );
      addTearDown(container.dispose);
      final notifier = container.read(pactTimelineViewModelProvider(_pactId).notifier);
      await notifier.load();
      final single = container
          .read(pactTimelineViewModelProvider(_pactId))
          .visibleMilestones
          .whereType<SingleShowupMilestone>()
          .first;
      notifier.onMilestoneTapped(single);
      final event = analytics.loggedEvents.whereType<PactTimelineMilestoneTappedEvent>().single;
      expect(event.pactId, _pactId);
      expect(event.itemType, 'single_showup');
    });
  });
}

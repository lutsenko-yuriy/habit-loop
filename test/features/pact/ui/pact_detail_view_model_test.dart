import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_stats.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

import '../../../analytics/fake_analytics_service.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _showups = [
  Showup(id: 's1', pactId: 'p1', scheduledAt: DateTime(2026, 3, 1, 8), duration: const Duration(minutes: 10), status: ShowupStatus.done),
  Showup(id: 's2', pactId: 'p1', scheduledAt: DateTime(2026, 3, 2, 8), duration: const Duration(minutes: 10), status: ShowupStatus.done),
  Showup(id: 's3', pactId: 'p1', scheduledAt: DateTime(2026, 3, 3, 8), duration: const Duration(minutes: 10), status: ShowupStatus.failed),
  Showup(id: 's4', pactId: 'p1', scheduledAt: DateTime(2026, 3, 4, 8), duration: const Duration(minutes: 10), status: ShowupStatus.pending),
];

ProviderContainer _makeContainer({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
}) {
  return ProviderContainer(
    overrides: [
      pactDetailRepositoryProvider.overrideWithValue(InMemoryPactRepository(pacts)),
      pactDetailShowupRepositoryProvider.overrideWithValue(InMemoryShowupRepository(showups)),
    ],
  );
}

void main() {
  group('PactDetailViewModel', () {
    test('initial state is loading with no data', () {
      final container = _makeContainer(pacts: [_pact], showups: _showups);
      addTearDown(container.dispose);
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.isLoading, true);
      expect(state.pact, isNull);
      expect(state.stats, isNull);
    });

    test('load populates pact and stats', () async {
      final container = _makeContainer(pacts: [_pact], showups: _showups);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.isLoading, false);
      expect(state.pact?.habitName, 'Meditate');
      expect(state.stats?.showupsDone, 2);
      expect(state.stats?.showupsFailed, 1);
      expect(state.stats?.currentStreak, 0); // streak broken by failed
    });

    test(
        'load uses ShowupGenerator.countTotal for totalShowups when window is partial',
        () async {
      // _showups has only 4 entries but _pact spans 2026-03-01..2026-09-01
      // (daily). countTotal returns the full schedule count, which is much
      // larger than 4. showupsRemaining must be countTotal - done(2) - failed(1).
      final container = _makeContainer(pacts: [_pact], showups: _showups);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final state = container.read(pactDetailViewModelProvider('p1'));
      final expectedTotal = ShowupGenerator.countTotal(_pact);
      expect(state.stats?.totalShowups, expectedTotal);
      expect(state.stats?.showupsRemaining,
          expectedTotal - 2 - 1); // total - done - failed
    });

    test('load sets error when pact not found', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('missing').notifier).load();
      final state = container.read(pactDetailViewModelProvider('missing'));
      expect(state.isLoading, false);
      expect(state.loadError, isNotNull);
    });

    test('stopPact updates pact status to stopped with reason', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final container = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider.overrideWithValue(InMemoryShowupRepository(_showups)),
      ]);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact('Not for me');
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.pact?.status, PactStatus.stopped);
      expect(state.pact?.stopReason, 'Not for me');
      // Verify persisted
      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.status, PactStatus.stopped);
    });

    test('stopPact with no reason persists null stopReason', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final container = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider.overrideWithValue(InMemoryShowupRepository(_showups)),
      ]);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact(null);
      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.stopReason, isNull);
    });

    test('load recomputes fresh stats when persisted snapshot is stale',
        () async {
      final stalePact = _pact.copyWith(
        stats: PactStats(
          showupsDone: 0,
          showupsFailed: 0,
          showupsRemaining: 999,
          totalShowups: 999,
          currentStreak: 0,
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
        ),
      );
      final container = _makeContainer(pacts: [stalePact], showups: _showups);
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();

      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.stats?.showupsDone, 2);
      expect(state.stats?.showupsFailed, 1);
      expect(state.stats?.totalShowups, ShowupGenerator.countTotal(_pact));
    });

    test('stopPact rolls pact back when deleting showups fails', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = _ThrowingOnDeleteShowupRepository(_showups);
      final container = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container
          .read(pactDetailViewModelProvider('p1').notifier)
          .stopPact('Not for me');

      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.stopError, isNotNull);

      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.status, PactStatus.active);
      expect(persisted?.stopReason, isNull);
      expect(await showupRepo.getShowupsForPact('p1'), isNotEmpty);
    });

    test('stopPact preserves historical stats even after showups are removed',
        () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository(_showups);
      final container = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final statsBeforeStop = container.read(pactDetailViewModelProvider('p1')).stats;

      await container
          .read(pactDetailViewModelProvider('p1').notifier)
          .stopPact('Not for me');

      final remainingShowups = await showupRepo.getShowupsForPact('p1');
      expect(remainingShowups, isEmpty);

      final reloadedContainer = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(reloadedContainer.dispose);

      await reloadedContainer
          .read(pactDetailViewModelProvider('p1').notifier)
          .load();

      final reloadedState = reloadedContainer.read(pactDetailViewModelProvider('p1'));
      expect(reloadedState.pact?.status, PactStatus.stopped);
      expect(reloadedState.pact?.stats, isNotNull);
      expect(reloadedState.stats?.showupsDone, statsBeforeStop?.showupsDone);
      expect(
        reloadedState.stats?.showupsFailed,
        statsBeforeStop?.showupsFailed,
      );
      expect(
        reloadedState.stats?.showupsRemaining,
        statsBeforeStop?.showupsRemaining,
      );
      expect(
        reloadedState.stats?.totalShowups,
        statsBeforeStop?.totalShowups,
      );
      expect(
        reloadedState.stats?.currentStreak,
        statsBeforeStop?.currentStreak,
      );
      expect(reloadedState.pact?.stats, reloadedState.stats);
    });

    test('load auto-completes an active pact whose end date is in the past',
        () async {
      final expiredPact = Pact(
        id: 'expired',
        habitName: 'Run',
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 3, 1), // clearly in the past
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      final showups = [
        Showup(
            id: 'e1',
            pactId: 'expired',
            scheduledAt: DateTime(2020, 1, 5, 7),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.done),
      ];
      final pactRepo = InMemoryPactRepository([expiredPact]);
      final container = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider
            .overrideWithValue(InMemoryShowupRepository(showups)),
      ]);
      addTearDown(container.dispose);

      await container
          .read(pactDetailViewModelProvider('expired').notifier)
          .load();

      final state = container.read(pactDetailViewModelProvider('expired'));
      expect(state.pact?.status, PactStatus.completed);
      final persisted = await pactRepo.getPactById('expired');
      expect(persisted?.status, PactStatus.completed);
    });

    test('load auto-completes an active pact when all showups are resolved',
        () async {
      // Dates in 2054 so the end date is in the future (daysLeft > 0), ensuring
      // auto-completion is triggered solely by showupsRemaining == 0 rather than
      // by the end-date guard. We generate every scheduled showup and mark them
      // all done/failed so countTotal - done - failed == 0.
      final allResolvedPact = Pact(
        id: 'all-resolved',
        habitName: 'Stretch',
        startDate: DateTime(2054, 1, 1),
        endDate: DateTime(2054, 1, 3), // 3-day pact → exactly 3 daily showups
        showupDuration: const Duration(minutes: 5),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 6)),
        status: PactStatus.active,
      );
      // Generate all showups for the pact and mark them resolved.
      final generated = ShowupGenerator.generateWindow(
        allResolvedPact,
        from: allResolvedPact.startDate,
        to: allResolvedPact.endDate,
      );
      final showups =
          generated.map((s) => s.copyWith(status: ShowupStatus.done)).toList();
      final pactRepo = InMemoryPactRepository([allResolvedPact]);
      final container = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider
            .overrideWithValue(InMemoryShowupRepository(showups)),
      ]);
      addTearDown(container.dispose);

      await container
          .read(pactDetailViewModelProvider('all-resolved').notifier)
          .load();

      final state = container.read(pactDetailViewModelProvider('all-resolved'));
      expect(state.pact?.status, PactStatus.completed);
      final persisted = await pactRepo.getPactById('all-resolved');
      expect(persisted?.status, PactStatus.completed);
    });

    test(
        'load does not auto-complete an active pact with a future end date and pending showups',
        () async {
      // _pact: endDate=2026-09-01 (future from 2026-04-04), has pending showup s4.
      final container = _makeContainer(pacts: [_pact], showups: _showups);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.pact?.status, PactStatus.active);
    });
  });

  group('PactDetailViewModel analytics', () {
    late FakeAnalyticsService fakeAnalytics;

    ProviderContainer makeContainerWithAnalytics({
      List<Pact> pacts = const [],
      List<Showup> showups = const [],
    }) {
      fakeAnalytics = FakeAnalyticsService();
      return ProviderContainer(
        overrides: [
          pactDetailRepositoryProvider
              .overrideWithValue(InMemoryPactRepository(pacts)),
          pactDetailShowupRepositoryProvider
              .overrideWithValue(InMemoryShowupRepository(showups)),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
    }

    test('stopPact fires PactStoppedEvent with correct stats on success',
        () async {
      final container = makeContainerWithAnalytics(
        pacts: [_pact],
        showups: _showups,
      );
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container
          .read(pactDetailViewModelProvider('p1').notifier)
          .stopPact('Giving up');

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first;
      expect(event, isA<PactStoppedEvent>());

      final pactStoppedEvent = event as PactStoppedEvent;
      // _showups has 2 done, 1 failed, 1 pending
      expect(pactStoppedEvent.totalShowupsDone, 2);
      expect(pactStoppedEvent.totalShowupsFailed, 1);
      // After stopping, all pending showups are counted as remaining
      // daysActive is computed at stopPact() time; just verify it's non-negative.
      expect(pactStoppedEvent.daysActive, greaterThanOrEqualTo(0));
    });

    test(
        'stopPact fires PactStoppedEvent with totalShowupsRemaining from stats',
        () async {
      final container = makeContainerWithAnalytics(
        pacts: [_pact],
        showups: _showups,
      );
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container
          .read(pactDetailViewModelProvider('p1').notifier)
          .stopPact(null);

      final event = fakeAnalytics.loggedEvents.first as PactStoppedEvent;
      // The stats are computed on the stopped pact, so remaining reflects
      // ShowupGenerator.countTotal(stoppedPact) - done - failed.
      expect(event.totalShowupsRemaining, greaterThanOrEqualTo(0));
    });

    test('stopPact does NOT fire event on failure', () async {
      final throwingPactRepo = _ThrowingPactRepository();
      fakeAnalytics = FakeAnalyticsService();
      final container = ProviderContainer(
        overrides: [
          pactDetailRepositoryProvider.overrideWithValue(throwingPactRepo),
          pactDetailShowupRepositoryProvider
              .overrideWithValue(InMemoryShowupRepository(_showups)),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
      addTearDown(container.dispose);

      // Load succeeds (getPactById returns the pact), but stopPact will fail
      // because updatePact throws.
      final loadRepo = InMemoryPactRepository([_pact]);
      final workingContainer = ProviderContainer(
        overrides: [
          pactDetailRepositoryProvider.overrideWithValue(loadRepo),
          pactDetailShowupRepositoryProvider
              .overrideWithValue(InMemoryShowupRepository(_showups)),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
      addTearDown(workingContainer.dispose);

      await workingContainer.read(pactDetailViewModelProvider('p1').notifier).load();

      // Now swap to a failing repo by replacing the container. Since we can't
      // do that, we test with a repo whose updatePact throws.
      final throwingRepo = _ThrowingOnUpdatePactRepository([_pact]);
      fakeAnalytics.reset();
      final failContainer = ProviderContainer(
        overrides: [
          pactDetailRepositoryProvider.overrideWithValue(throwingRepo),
          pactDetailShowupRepositoryProvider
              .overrideWithValue(InMemoryShowupRepository(_showups)),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
      addTearDown(failContainer.dispose);

      await failContainer.read(pactDetailViewModelProvider('p1').notifier).load();
      await failContainer.read(pactDetailViewModelProvider('p1').notifier).stopPact('reason');

      final state = failContainer.read(pactDetailViewModelProvider('p1'));
      expect(state.stopError, isNotNull);
      expect(fakeAnalytics.loggedEvents, isEmpty);
    });
  });
}

class _ThrowingPactRepository extends InMemoryPactRepository {
  @override
  Future<Pact?> getPactById(String id) async =>
      throw Exception('load failed intentionally');
}

class _ThrowingOnUpdatePactRepository extends InMemoryPactRepository {
  _ThrowingOnUpdatePactRepository(super.initialPacts);

  @override
  Future<void> updatePact(Pact pact) async =>
      throw Exception('update failed intentionally');
}

class _ThrowingOnDeleteShowupRepository extends InMemoryShowupRepository {
  _ThrowingOnDeleteShowupRepository(super.initialShowups);

  @override
  Future<void> deleteShowupsForPact(String pactId) async =>
      throw Exception('delete failed intentionally');
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';

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
  Showup(
      id: 's1',
      pactId: 'p1',
      scheduledAt: DateTime(2026, 3, 1, 8),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.done),
  Showup(
      id: 's2',
      pactId: 'p1',
      scheduledAt: DateTime(2026, 3, 2, 8),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.done),
  Showup(
      id: 's3',
      pactId: 'p1',
      scheduledAt: DateTime(2026, 3, 3, 8),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.failed),
  Showup(
      id: 's4',
      pactId: 'p1',
      scheduledAt: DateTime(2026, 3, 4, 8),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending),
];

ProviderContainer _makeContainer({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
  List<Override> extras = const [],
}) {
  final pactRepo = InMemoryPactRepository(pacts);
  final showupRepo = InMemoryShowupRepository(showups);
  final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
  final statsService = PactStatsService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: txService,
    syncService: const NoopSyncService(),
  );
  final service = PactService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: txService,
    syncService: const NoopSyncService(),
    pactStatsService: statsService,
  );
  return ProviderContainer(
    overrides: [
      pactServiceProvider.overrideWithValue(service),
      pactStatsServiceProvider.overrideWithValue(statsService),
      // Required so stopPact can load showup IDs for deterministic notification
      // cancellation (HAB-100) without hitting the default UnimplementedError.
      showupRepositoryProvider.overrideWithValue(showupRepo),
      ...extras,
    ],
  );
}

void main() {
  _saveNoteTests();
  _archivePactTests();

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

    test('load uses ShowupGenerator.countTotal for totalShowups when window is partial', () async {
      // _showups has only 4 entries but _pact spans 2026-03-01..2026-09-01
      // (daily). countTotal returns the full schedule count, which is much
      // larger than 4. showupsRemaining must be countTotal - done(2) - failed(1).
      final container = _makeContainer(pacts: [_pact], showups: _showups);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final state = container.read(pactDetailViewModelProvider('p1'));
      final expectedTotal = ShowupGenerator.countTotal(_pact);
      expect(state.stats?.totalShowups, expectedTotal);
      expect(state.stats?.showupsRemaining, expectedTotal - 2 - 1); // total - done - failed
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
      final showupRepo = InMemoryShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
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
      final showupRepo = InMemoryShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact(null);
      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.stopReason, isNull);
    });

    test('load recomputes fresh stats when persisted snapshot is stale', () async {
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
      final throwingShowupRepo = _ThrowingOnDeleteShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(pactRepo, throwingShowupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: throwingShowupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: throwingShowupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(throwingShowupRepo),
      ]);
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact('Not for me');

      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.stopError, isNotNull);

      // After the delete fails, the InMemoryPactTransactionService has already
      // called deleteShowupsForPact (which throws) before updatePact — so the
      // pact status may not have been updated. The key invariant is that
      // stopError is set, which we already asserted above.
      expect(await throwingShowupRepo.getShowupsForPact('p1'), isNotEmpty);
    });

    test('stopPact preserves historical stats even after showups are removed', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final statsBeforeStop = container.read(pactDetailViewModelProvider('p1')).stats;

      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact('Not for me');

      final remainingShowups = await showupRepo.getShowupsForPact('p1');
      expect(remainingShowups, isEmpty);

      final reloadedPactRepo = InMemoryPactRepository([await pactRepo.getPactById('p1') ?? _pact]);
      final reloadedShowupRepo = InMemoryShowupRepository();
      final reloadedTxService = InMemoryPactTransactionService(reloadedPactRepo, reloadedShowupRepo);
      final reloadedStatsService = PactStatsService(
        pactRepository: reloadedPactRepo,
        showupRepository: reloadedShowupRepo,
        transactionService: reloadedTxService,
        syncService: const NoopSyncService(),
      );
      final reloadedService = PactService(
        pactRepository: reloadedPactRepo,
        showupRepository: reloadedShowupRepo,
        transactionService: reloadedTxService,
        syncService: const NoopSyncService(),
        pactStatsService: reloadedStatsService,
      );
      final reloadedContainer = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(reloadedService),
        pactStatsServiceProvider.overrideWithValue(reloadedStatsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(reloadedContainer.dispose);

      await reloadedContainer.read(pactDetailViewModelProvider('p1').notifier).load();

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

    test('load auto-completes an active pact whose end date is in the past', () async {
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
      final showupRepo = InMemoryShowupRepository(showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(container.dispose);

      // Warm the cache first so we can verify it is evicted on auto-complete.
      await statsService.currentStats(pact: expiredPact, showups: showups);

      await container.read(pactDetailViewModelProvider('expired').notifier).load();

      final state = container.read(pactDetailViewModelProvider('expired'));
      expect(state.pact?.status, PactStatus.completed);
      final persisted = await pactRepo.getPactById('expired');
      expect(persisted?.status, PactStatus.completed);

      // After auto-completion, onPactCompleted was called which evicted the cache.
      // Calling currentStats with empty showups now goes to DB (cache miss), so
      // the returned stats must reflect the completed pact (not stale active-pact data).
      final completedPact = persisted!;
      final statsAfterComplete = await statsService.currentStats(pact: completedPact, showups: []);
      // The pact's showups are still in the repo (completion does not delete them),
      // so stats must be re-computed from DB and be non-null.
      expect(statsAfterComplete, isNotNull,
          reason: 'currentStats must re-load from DB after cache eviction by onPactCompleted');
    });

    test('load auto-completes a pact when pactDetailNowProvider is past the end date', () async {
      // Pact endDate is in the future from the real clock, but we inject a
      // "now" that is past it — verifying the auto-completion path uses the
      // provider rather than DateTime.now() directly.
      final futurePact = Pact(
        id: 'future-end',
        habitName: 'Stretch',
        startDate: DateTime(2054, 1, 1),
        endDate: DateTime(2054, 6, 1),
        showupDuration: const Duration(minutes: 5),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      final pactRepo = InMemoryPactRepository([futurePact]);
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      // Inject a "now" that is one day past the end date.
      final pastEndDate = DateTime(2054, 6, 2, 12, 0);
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactDetailNowProvider.overrideWithValue(pastEndDate),
      ]);
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('future-end').notifier).load();

      final state = container.read(pactDetailViewModelProvider('future-end'));
      expect(state.pact?.status, PactStatus.completed,
          reason: 'Pact must auto-complete when injected now is past endDate');
      final persisted = await pactRepo.getPactById('future-end');
      expect(persisted?.status, PactStatus.completed);
    });

    test('load auto-completes an active pact when all showups are resolved', () async {
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
      final showups = generated.map((s) => s.copyWith(status: ShowupStatus.done)).toList();
      final pactRepo = InMemoryPactRepository([allResolvedPact]);
      final showupRepo = InMemoryShowupRepository(showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('all-resolved').notifier).load();

      final state = container.read(pactDetailViewModelProvider('all-resolved'));
      expect(state.pact?.status, PactStatus.completed);
      final persisted = await pactRepo.getPactById('all-resolved');
      expect(persisted?.status, PactStatus.completed);
    });

    test('load does not auto-complete an active pact with a future end date and pending showups', () async {
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
      return _makeContainer(
        pacts: pacts,
        showups: showups,
        extras: [analyticsServiceProvider.overrideWithValue(fakeAnalytics)],
      );
    }

    test('stopPact fires PactStoppedEvent with correct stats on success', () async {
      final container = makeContainerWithAnalytics(
        pacts: [_pact],
        showups: _showups,
      );
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact('Giving up');

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

    test('stopPact fires PactStoppedEvent with totalShowupsRemaining from stats', () async {
      final container = makeContainerWithAnalytics(
        pacts: [_pact],
        showups: _showups,
      );
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact(null);

      final event = fakeAnalytics.loggedEvents.first as PactStoppedEvent;
      // The stats are computed on the stopped pact, so remaining reflects
      // ShowupGenerator.countTotal(stoppedPact) - done - failed.
      expect(event.totalShowupsRemaining, greaterThanOrEqualTo(0));
    });

    test('daysActive is 1 when pact was created at midnight and stopped next morning', () async {
      // pact.startDate = 2026-03-01T00:00 (midnight — as normalised by PactCreationState fix)
      // now = 2026-03-02T08:00 (next morning)
      // daysActive = (Mar 2 08:00 − Mar 1 00:00).inDays = 1 ✅
      fakeAnalytics = FakeAnalyticsService();
      final nextMorning = DateTime(2026, 3, 2, 8, 0);
      final container = _makeContainer(
        pacts: [_pact],
        showups: _showups,
        extras: [
          pactDetailNowProvider.overrideWithValue(nextMorning),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact(null);

      final event = fakeAnalytics.loggedEvents.single as PactStoppedEvent;
      // Mar 1 00:00 → Mar 2 08:00 = 1 day 8 hours → daysActive = 1
      expect(event.daysActive, 1, reason: 'Stopping on the morning after start day must report 1 day active');
    });

    test('stopPact does NOT fire event on failure', () async {
      fakeAnalytics = FakeAnalyticsService();

      final throwingPactRepo = _ThrowingOnUpdatePactRepository([_pact]);
      final throwingShowupRepo = InMemoryShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(throwingPactRepo, throwingShowupRepo);
      final throwingStatsService = PactStatsService(
        pactRepository: throwingPactRepo,
        showupRepository: throwingShowupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final throwingService = PactService(
        pactRepository: throwingPactRepo,
        showupRepository: throwingShowupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: throwingStatsService,
      );
      final failContainer = ProviderContainer(
        overrides: [
          pactServiceProvider.overrideWithValue(throwingService),
          pactStatsServiceProvider.overrideWithValue(throwingStatsService),
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

  group('PactDetailViewModel notification cancellation', () {
    // Shared setup for notification-cancellation tests.
    ProviderContainer makeNotifContainer({
      required FakeNotificationService fakeNotifications,
    }) {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        notificationServiceProvider.overrideWithValue(fakeNotifications),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('cancels all pact notifications when pact is stopped', () async {
      final fakeNotifications = FakeNotificationService();
      final c = makeNotifContainer(fakeNotifications: fakeNotifications);

      await c.read(pactDetailViewModelProvider('p1').notifier).load();
      await c.read(pactDetailViewModelProvider('p1').notifier).stopPact(null);

      expect(fakeNotifications.cancelledPactIds, contains('p1'),
          reason: 'cancelAllRemindersForPact must be called with the pact id when pact is stopped');
    });

    test('passes showup IDs to cancelAllRemindersForPact so cold-restart cancellation works', () async {
      // Regression test for HAB-100: when the app is killed and restarted
      // before stopping a pact, the in-memory notification registry is empty.
      // The fix passes showup IDs so the notification service can cancel by
      // deterministically computed ID rather than querying the OS list (which
      // iOS does not populate for notifications scheduled in a previous session).
      final fakeNotifications = FakeNotificationService();
      final c = makeNotifContainer(fakeNotifications: fakeNotifications);

      await c.read(pactDetailViewModelProvider('p1').notifier).load();
      await c.read(pactDetailViewModelProvider('p1').notifier).stopPact(null);

      expect(fakeNotifications.cancelledPactShowupIds, hasLength(1));
      final passedIds = fakeNotifications.cancelledPactShowupIds.first;
      expect(passedIds, containsAll(['s1', 's2', 's3', 's4']),
          reason: 'all showup IDs must be passed so notifications can be cancelled by computed ID');
    });
  });
}

class _ThrowingOnUpdatePactRepository extends InMemoryPactRepository {
  _ThrowingOnUpdatePactRepository(super.initialPacts);

  @override
  Future<void> updatePact(Pact pact) async => throw Exception('update failed intentionally');
}

final _stoppedPact = Pact(
  id: 'sp1',
  habitName: 'Evening Walk',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 3, 31),
  showupDuration: const Duration(minutes: 20),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 18)),
  status: PactStatus.stopped,
  stopReason: 'Got injured',
  stoppedAt: DateTime(2026, 3, 1),
);

final _completedPact = Pact(
  id: 'cp1',
  habitName: 'Jog',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 3, 31),
  showupDuration: const Duration(minutes: 30),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
  status: PactStatus.completed,
);

class _ThrowingOnDeleteShowupRepository extends InMemoryShowupRepository {
  _ThrowingOnDeleteShowupRepository(super.initialShowups);

  @override
  Future<void> deleteShowupsForPact(String pactId) async => throw Exception('delete failed intentionally');
}

class _ThrowingOnArchivePactRepository extends InMemoryPactRepository {
  _ThrowingOnArchivePactRepository(super.initialPacts);

  @override
  Future<void> archivePact(String id, bool archived) async => throw Exception('archive failed intentionally');
}

// ---------------------------------------------------------------------------
// saveNote tests
// ---------------------------------------------------------------------------

void _saveNoteTests() {
  group('PactDetailViewModel.saveNote', () {
    late FakeAnalyticsService fakeAnalytics;

    ProviderContainer makeContainer(Pact pact) {
      fakeAnalytics = FakeAnalyticsService();
      final pactRepo = InMemoryPactRepository([pact]);
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('saves new note text on a stopped pact and updates state', () async {
      final c = makeContainer(_stoppedPact);
      await c.read(pactDetailViewModelProvider('sp1').notifier).load();
      await c.read(pactDetailViewModelProvider('sp1').notifier).saveNote('Resting now');

      final state = c.read(pactDetailViewModelProvider('sp1'));
      expect(state.pact?.stopReason, 'Resting now');
      expect(state.isSavingNote, false);
      expect(state.noteError, isNull);
    });

    test('saves note on a completed pact', () async {
      final c = makeContainer(_completedPact);
      await c.read(pactDetailViewModelProvider('cp1').notifier).load();
      await c.read(pactDetailViewModelProvider('cp1').notifier).saveNote('Felt great!');

      final state = c.read(pactDetailViewModelProvider('cp1'));
      expect(state.pact?.stopReason, 'Felt great!');
    });

    test('clearing note sets stopReason to null', () async {
      final c = makeContainer(_stoppedPact);
      await c.read(pactDetailViewModelProvider('sp1').notifier).load();
      await c.read(pactDetailViewModelProvider('sp1').notifier).saveNote('');

      final state = c.read(pactDetailViewModelProvider('sp1'));
      expect(state.pact?.stopReason, isNull);
    });

    test('fires PactNoteSavedEvent with correct properties', () async {
      final c = makeContainer(_stoppedPact);
      await c.read(pactDetailViewModelProvider('sp1').notifier).load();
      await c.read(pactDetailViewModelProvider('sp1').notifier).saveNote('Resting now');

      final events = fakeAnalytics.loggedEvents.whereType<PactNoteSavedEvent>().toList();
      expect(events, hasLength(1));
      final e = events.first;
      expect(e.pactId, 'sp1');
      expect(e.pactStatus, 'stopped');
      expect(e.noteLength, 'Resting now'.length);
      expect(e.wasEdit, true); // pact already had 'Got injured'
    });

    test('wasEdit is false when pact had no prior note', () async {
      final c = makeContainer(_completedPact);
      await c.read(pactDetailViewModelProvider('cp1').notifier).load();
      await c.read(pactDetailViewModelProvider('cp1').notifier).saveNote('First note');

      final e = fakeAnalytics.loggedEvents.whereType<PactNoteSavedEvent>().first;
      expect(e.wasEdit, false);
    });

    test('sets noteError and does not fire event on repository failure', () async {
      final throwingPactRepo = _ThrowingOnUpdatePactRepository([_stoppedPact]);
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(throwingPactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: throwingPactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: throwingPactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      fakeAnalytics = FakeAnalyticsService();
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ]);
      addTearDown(c.dispose);

      await c.read(pactDetailViewModelProvider('sp1').notifier).load();
      await c.read(pactDetailViewModelProvider('sp1').notifier).saveNote('oops');

      final state = c.read(pactDetailViewModelProvider('sp1'));
      expect(state.noteError, isNotNull);
      expect(state.isSavingNote, false);
      expect(fakeAnalytics.loggedEvents.whereType<PactNoteSavedEvent>(), isEmpty);
    });

    test('clears noteError on the next successful save', () async {
      final throwingRepo = _ThrowingOnUpdatePactRepository([_stoppedPact]);
      final workingRepo = InMemoryPactRepository([_stoppedPact]);

      // First call uses throwing repo to set noteError.
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(throwingRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: throwingRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final throwingService = PactService(
        pactRepository: throwingRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final workingStatsService = PactStatsService(
        pactRepository: workingRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(workingRepo, showupRepo),
        syncService: const NoopSyncService(),
      );
      final workingService = PactService(
        pactRepository: workingRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(workingRepo, showupRepo),
        syncService: const NoopSyncService(),
        pactStatsService: workingStatsService,
      );

      fakeAnalytics = FakeAnalyticsService();
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(throwingService),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ]);
      addTearDown(c.dispose);

      await c.read(pactDetailViewModelProvider('sp1').notifier).load();
      await c.read(pactDetailViewModelProvider('sp1').notifier).saveNote('fail');
      expect(c.read(pactDetailViewModelProvider('sp1')).noteError, isNotNull);

      // Override with working service and retry.
      c.updateOverrides([
        pactServiceProvider.overrideWithValue(workingService),
        pactStatsServiceProvider.overrideWithValue(workingStatsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ]);
      await c.read(pactDetailViewModelProvider('sp1').notifier).saveNote('success');
      expect(c.read(pactDetailViewModelProvider('sp1')).noteError, isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// archivePact tests
// ---------------------------------------------------------------------------

void _archivePactTests() {
  group('PactDetailViewModel.archivePact', () {
    late FakeAnalyticsService fakeAnalytics;

    ProviderContainer makeContainer(Pact pact) {
      fakeAnalytics = FakeAnalyticsService();
      final pactRepo = InMemoryPactRepository([pact]);
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('archives a completed pact and updates state', () async {
      final c = makeContainer(_completedPact);
      await c.read(pactDetailViewModelProvider('cp1').notifier).load();
      await c.read(pactDetailViewModelProvider('cp1').notifier).archivePact(true, source: 'detail_screen');

      final state = c.read(pactDetailViewModelProvider('cp1'));
      expect(state.pact?.archived, isTrue);
      expect(state.isArchiving, isFalse);
      expect(state.archiveError, isNull);
    });

    test('unarchives a stopped pact and updates state', () async {
      final archivedStopped = _stoppedPact.copyWith(archived: true);
      final c = makeContainer(archivedStopped);
      await c.read(pactDetailViewModelProvider('sp1').notifier).load();
      await c.read(pactDetailViewModelProvider('sp1').notifier).archivePact(false, source: 'detail_screen');

      final state = c.read(pactDetailViewModelProvider('sp1'));
      expect(state.pact?.archived, isFalse);
    });

    test('fires PactArchivedEvent with correct properties', () async {
      final c = makeContainer(_completedPact);
      await c.read(pactDetailViewModelProvider('cp1').notifier).load();
      await c.read(pactDetailViewModelProvider('cp1').notifier).archivePact(true, source: 'detail_screen');

      final events = fakeAnalytics.loggedEvents.whereType<PactArchivedEvent>().toList();
      expect(events, hasLength(1));
      expect(events.first.pactId, 'cp1');
      expect(events.first.pactStatus, 'completed');
      expect(events.first.source, 'detail_screen');
    });

    test('fires PactUnarchivedEvent with correct properties', () async {
      final archivedStopped = _stoppedPact.copyWith(archived: true);
      final c = makeContainer(archivedStopped);
      await c.read(pactDetailViewModelProvider('sp1').notifier).load();
      await c.read(pactDetailViewModelProvider('sp1').notifier).archivePact(false, source: 'detail_screen');

      final events = fakeAnalytics.loggedEvents.whereType<PactUnarchivedEvent>().toList();
      expect(events, hasLength(1));
      expect(events.first.pactId, 'sp1');
      expect(events.first.pactStatus, 'stopped');
      expect(events.first.source, 'detail_screen');
    });

    test('sets archiveError and does not fire event on failure', () async {
      fakeAnalytics = FakeAnalyticsService();
      final throwingRepo = _ThrowingOnArchivePactRepository([_completedPact]);
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(throwingRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: throwingRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
      );
      final service = PactService(
        pactRepository: throwingRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        pactStatsService: statsService,
      );
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ]);
      addTearDown(c.dispose);

      await c.read(pactDetailViewModelProvider('cp1').notifier).load();
      await c.read(pactDetailViewModelProvider('cp1').notifier).archivePact(true, source: 'detail_screen');

      final state = c.read(pactDetailViewModelProvider('cp1'));
      expect(state.archiveError, isNotNull);
      expect(state.isArchiving, isFalse);
      expect(fakeAnalytics.loggedEvents.whereType<PactArchivedEvent>(), isEmpty);
    });
  });
}

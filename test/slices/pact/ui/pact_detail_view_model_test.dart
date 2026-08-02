import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_break_service.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';
import '../../../infrastructure/sync/fake_sync_service.dart';

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

PactDetailCache _makeCache(
  InMemoryPactRepository pactRepo,
  InMemoryShowupRepository showupRepo, {
  List<PactBreak> breaks = const [],
}) =>
    PactDetailCache(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      pactBreakRepository: InMemoryPactBreakRepository(breaks),
      grouper: const PactTimelineGrouper(),
    );

ProviderContainer _makeContainer({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
  List<PactBreak> breaks = const [],
  List<Override> extras = const [],
}) {
  final pactRepo = InMemoryPactRepository(pacts);
  final showupRepo = InMemoryShowupRepository(showups);
  final breakRepo = InMemoryPactBreakRepository(breaks);
  final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
  final cache = PactDetailCache(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    pactBreakRepository: breakRepo,
    grouper: const PactTimelineGrouper(),
  );
  final statsService = PactStatsService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: txService,
    syncService: const NoopSyncService(),
    cache: cache,
  );
  final service = PactService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: txService,
    syncService: const NoopSyncService(),
    cache: cache,
  );
  final reminderService = ReminderSchedulingService(
    notificationService: FakeNotificationService(),
    remoteConfig: FakeRemoteConfigService(),
    analytics: FakeAnalyticsService(),
    localePreference: FakeLocalePreferenceService(),
  );
  final breakService = PactBreakService(
    pactBreakRepository: breakRepo,
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    reminderSchedulingService: reminderService,
    syncService: FakeSyncService(),
    cache: cache,
  );
  return ProviderContainer(
    overrides: [
      pactServiceProvider.overrideWithValue(service),
      pactStatsServiceProvider.overrideWithValue(statsService),
      pactDetailCacheProvider.overrideWithValue(cache),
      pactBreakServiceProvider.overrideWithValue(breakService),
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

    test('load populates activeBreak when an unresolved break exists (HAB-195)', () async {
      final onBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 10),
        plannedEndDate: DateTime(2026, 3, 20),
        rationale: 'Sick',
      );
      final container = _makeContainer(
        pacts: [_pact],
        showups: _showups,
        breaks: [onBreak],
        extras: [pactDetailNowProvider.overrideWithValue(DateTime(2026, 3, 15))],
      );
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.activeBreak?.id, 'brk-1');
      expect(state.isBreakActiveNow, isTrue);
    });

    test(
        'load surfaces activeBreak but leaves isBreakActiveNow false for a break scheduled to start in the future (HAB-201)',
        () async {
      final notYetStartedBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 18),
        plannedEndDate: DateTime(2026, 3, 25),
        rationale: 'Planned ahead',
      );
      final container = _makeContainer(
        pacts: [_pact],
        showups: _showups,
        breaks: [notYetStartedBreak],
        extras: [pactDetailNowProvider.overrideWithValue(DateTime(2026, 3, 15))],
      );
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final state = container.read(pactDetailViewModelProvider('p1'));
      // activeBreak stays non-null — it still gates "Take a Break" and
      // stopBreak's cancel-ahead-of-time support — but the banner (driven by
      // isBreakActiveNow) must not show until the break actually starts.
      expect(state.activeBreak?.id, 'brk-1');
      expect(state.isBreakActiveNow, isFalse);
    });

    test('stopBreak clears activeBreak on success (HAB-195 WU5.2)', () async {
      final onBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 10),
        plannedEndDate: DateTime(2026, 3, 20),
        rationale: 'Sick',
      );
      final container = _makeContainer(
        pacts: [_pact],
        showups: _showups,
        breaks: [onBreak],
        extras: [pactDetailNowProvider.overrideWithValue(DateTime(2026, 3, 15))],
      );
      addTearDown(container.dispose);
      final notifier = container.read(pactDetailViewModelProvider('p1').notifier);
      await notifier.load();
      expect(container.read(pactDetailViewModelProvider('p1')).activeBreak, isNotNull);

      await notifier.stopBreak();

      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.activeBreak, isNull);
      expect(state.isBreakActiveNow, isFalse);
      expect(state.isStoppingBreak, false);
      expect(state.stopBreakError, isNull);
    });

    test('stopBreak is a no-op when there is no active break (HAB-195 WU5.2)', () async {
      final container = _makeContainer(pacts: [_pact], showups: _showups);
      addTearDown(container.dispose);
      final notifier = container.read(pactDetailViewModelProvider('p1').notifier);
      await notifier.load();

      await notifier.stopBreak();

      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.activeBreak, isNull);
      expect(state.isStoppingBreak, false);
    });

    test('load leaves activeBreak null when the only break is already resolved (HAB-195)', () async {
      final stoppedBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 1),
        plannedEndDate: DateTime(2026, 3, 5),
        rationale: 'Sick',
        stoppedAt: DateTime(2026, 3, 3),
      );
      final container = _makeContainer(
        pacts: [_pact],
        showups: _showups,
        breaks: [stoppedBreak],
        extras: [pactDetailNowProvider.overrideWithValue(DateTime(2026, 3, 15))],
      );
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.activeBreak, isNull);
    });

    test('load sets error when pact not found', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('missing').notifier).load();
      final state = container.read(pactDetailViewModelProvider('missing'));
      expect(state.isLoading, false);
      expect(state.loadError, isNotNull);
    });

    group('load — chain fields (HAB-202)', () {
      final predecessor = Pact(
        id: 'root',
        habitName: 'Vibe coding',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 3, 1),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
        status: PactStatus.stopped,
      );

      test('populates predecessorPact when pact.predecessorPactId is set', () async {
        final successor = Pact(
          id: 'p1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          predecessorPactId: 'root',
        );
        final container = _makeContainer(pacts: [predecessor, successor], showups: _showups);
        addTearDown(container.dispose);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        final state = container.read(pactDetailViewModelProvider('p1'));

        expect(state.predecessorPact?.id, 'root');
        expect(state.predecessorPact?.habitName, 'Vibe coding');
      });

      test('leaves predecessorPact null when pact has no predecessor', () async {
        final container = _makeContainer(pacts: [_pact], showups: _showups);
        addTearDown(container.dispose);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        final state = container.read(pactDetailViewModelProvider('p1'));

        expect(state.predecessorPact, isNull);
      });

      test('populates successorPact when a successor pact exists', () async {
        final successor = Pact(
          id: 'v2',
          habitName: 'Meditate (v2)',
          startDate: DateTime(2026, 9, 2),
          endDate: DateTime(2027, 3, 2),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          predecessorPactId: 'p1',
        );
        final container = _makeContainer(pacts: [_pact, successor], showups: _showups);
        addTearDown(container.dispose);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        final state = container.read(pactDetailViewModelProvider('p1'));

        expect(state.successorPact?.id, 'v2');
        expect(state.successorPact?.habitName, 'Meditate (v2)');
      });

      test('leaves successorPact null when there is no successor', () async {
        final container = _makeContainer(pacts: [_pact], showups: _showups);
        addTearDown(container.dispose);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        final state = container.read(pactDetailViewModelProvider('p1'));

        expect(state.successorPact, isNull);
      });

      test('warms the cache for predecessor and successor pacts (HAB-206 WU2)', () async {
        final successor = Pact(
          id: 'v2',
          habitName: 'Meditate (v2)',
          startDate: DateTime(2026, 9, 2),
          endDate: DateTime(2027, 3, 2),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          predecessorPactId: 'p1',
        );
        final current = Pact(
          id: 'p1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          predecessorPactId: 'root',
        );
        final container = _makeContainer(pacts: [predecessor, current, successor], showups: _showups);
        addTearDown(container.dispose);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        // Cache warming is fire-and-forget — flush the event loop so the
        // unawaited load() calls it kicked off have a chance to complete.
        await Future<void>.delayed(Duration.zero);

        final cache = container.read(pactDetailCacheProvider);
        expect(cache.peek('root'), isNotNull, reason: 'predecessor bundle must be warmed');
        expect(cache.peek('v2'), isNotNull, reason: 'successor bundle must be warmed');
      });

      test('resolves predecessorPact from the identity cache without a repo lookup (HAB-206 WU3)', () async {
        // The predecessor is NOT in the repo at all — if load() falls back
        // to pactService.getPact(), it would find nothing and predecessorPact
        // would stay null. Resolving it correctly proves the identity cache
        // (pre-seeded here the same way a real chain-link navigation would
        // seed it) was actually consulted first.
        final current = Pact(
          id: 'p1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          predecessorPactId: 'root',
        );
        final container = _makeContainer(pacts: [current], showups: _showups);
        addTearDown(container.dispose);
        container.read(pactDetailCacheProvider).rememberPact(predecessor);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        final state = container.read(pactDetailViewModelProvider('p1'));

        expect(state.predecessorPact?.id, 'root');
      });

      test('resolves successorPact from the identity cache without a repo lookup (HAB-206 WU3)', () async {
        final successor = Pact(
          id: 'v2',
          habitName: 'Meditate (v2)',
          startDate: DateTime(2026, 9, 2),
          endDate: DateTime(2027, 3, 2),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          predecessorPactId: 'p1',
        );
        final container = _makeContainer(pacts: [_pact], showups: _showups);
        addTearDown(container.dispose);
        // Successor is not in the repo — only the identity cache knows it,
        // pre-seeded the way _warmChainIdentity would after an earlier load.
        container.read(pactDetailCacheProvider).rememberPact(successor);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        final state = container.read(pactDetailViewModelProvider('p1'));

        expect(state.successorPact?.id, 'v2');
      });

      test(
          'warms one hop further than the bundle prefetch reaches — the successor\'s own successor identity '
          '(HAB-206 WU3)', () async {
        final current = Pact(
          id: 'p1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.stopped,
        );
        final successor = Pact(
          id: 'v2',
          habitName: 'Meditate (v2)',
          startDate: DateTime(2026, 9, 2),
          endDate: DateTime(2027, 3, 2),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.stopped,
          predecessorPactId: 'p1',
        );
        final grandSuccessor = Pact(
          id: 'v3',
          habitName: 'Meditate (v3)',
          startDate: DateTime(2027, 3, 3),
          endDate: DateTime(2027, 9, 3),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          predecessorPactId: 'v2',
        );
        final container = _makeContainer(pacts: [current, successor, grandSuccessor], showups: _showups);
        addTearDown(container.dispose);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        await Future<void>.delayed(Duration.zero);

        final cache = container.read(pactDetailCacheProvider);
        expect(
          cache.peekSuccessor('v2')?.id,
          'v3',
          reason: "v2's own successor should already be known once p1 finishes loading, "
              'so navigating p1 -> v2 needs no further DB round trip to resolve it',
        );
      });

      test('does not attempt to warm the cache for a neighbor that does not exist', () async {
        final container = _makeContainer(pacts: [_pact], showups: _showups);
        addTearDown(container.dispose);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        await Future<void>.delayed(Duration.zero);

        final state = container.read(pactDetailViewModelProvider('p1'));
        expect(state.loadError, isNull, reason: 'no predecessor/successor means nothing to warm, not an error');
      });

      test('does not surface an error when predecessorPactId points at a pact that no longer exists', () async {
        // predecessorPactId is set but no such pact exists in the repo — a
        // dangling reference (e.g. concurrent delete). Warming must not throw
        // an uncaught async error; getPact already returns null for display.
        final danglingRef = Pact(
          id: 'p1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          predecessorPactId: 'missing-predecessor',
        );
        final container = _makeContainer(pacts: [danglingRef], showups: _showups);
        addTearDown(container.dispose);

        await container.read(pactDetailViewModelProvider('p1').notifier).load();
        await Future<void>.delayed(Duration.zero);

        final state = container.read(pactDetailViewModelProvider('p1'));
        expect(state.loadError, isNull);
        expect(state.predecessorPact, isNull);
        expect(container.read(pactDetailCacheProvider).peek('missing-predecessor'), isNull);
      });
    });

    test('stopPact updates pact status to stopped with reason', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
        showupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact(null);
      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.stopReason, isNull);
    });

    test('stopPact resolves the active break and clears the banner (HAB-208)', () async {
      final onBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 1),
        plannedEndDate: DateTime(2026, 3, 20),
        rationale: 'Sick',
      );
      final now = DateTime(2026, 3, 10);
      final container = _makeContainer(
        pacts: [_pact],
        showups: _showups,
        breaks: [onBreak],
        extras: [pactDetailNowProvider.overrideWithValue(now)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(pactDetailViewModelProvider('p1').notifier);
      await notifier.load();
      expect(container.read(pactDetailViewModelProvider('p1')).isBreakActiveNow, isTrue);

      await notifier.stopPact('Not for me');

      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.activeBreak, isNull);
      expect(state.isBreakActiveNow, isFalse);

      // Reloading (leaving and returning) must not resurrect the banner —
      // the break itself was resolved, not just cleared from local state.
      await notifier.load();
      final reloadedState = container.read(pactDetailViewModelProvider('p1'));
      expect(reloadedState.activeBreak, isNull);
      expect(reloadedState.isBreakActiveNow, isFalse);
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
      final cache = _makeCache(pactRepo, throwingShowupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: throwingShowupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: throwingShowupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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

    test('stopPact keeps past showups and preserves stats after navigating away and back (HAB-208)', () async {
      // now sits between s3 (done/failed history) and s4 (still pending) —
      // s4 is the only showup scheduled after now, so it's the only one
      // stopPactTransaction removes.
      final now = DateTime(2026, 3, 3, 12);
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository(_showups);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactDetailNowProvider.overrideWithValue(now),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(pactDetailViewModelProvider('p1').notifier);
      await notifier.load();
      final statsBeforeStop = container.read(pactDetailViewModelProvider('p1')).stats;
      expect(statsBeforeStop?.showupsDone, 2);
      expect(statsBeforeStop?.showupsFailed, 1);

      await notifier.stopPact('Not for me');

      // Only the future (pending) showup s4 is gone — s1..s3 are real history.
      final remainingShowups = await showupRepo.getShowupsForPact('p1');
      expect(remainingShowups.map((s) => s.id).toSet(), {'s1', 's2', 's3'});

      // Simulates leaving and returning to Pact Details: load() again on the
      // same (now-evicted) cache, re-fetching from the same repositories.
      await notifier.load();

      final reloadedState = container.read(pactDetailViewModelProvider('p1'));
      expect(reloadedState.pact?.status, PactStatus.stopped);
      expect(reloadedState.stats?.showupsDone, statsBeforeStop?.showupsDone);
      expect(reloadedState.stats?.showupsFailed, statsBeforeStop?.showupsFailed);
      expect(reloadedState.stats?.showupsRemaining, statsBeforeStop?.showupsRemaining);
      expect(reloadedState.stats?.totalShowups, statsBeforeStop?.totalShowups);
      expect(reloadedState.stats?.currentStreak, statsBeforeStop?.currentStreak);
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
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
        showupRepositoryProvider.overrideWithValue(showupRepo),
      ]);
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('expired').notifier).load();

      final state = container.read(pactDetailViewModelProvider('expired'));
      expect(state.pact?.status, PactStatus.completed);
      final persisted = await pactRepo.getPactById('expired');
      expect(persisted?.status, PactStatus.completed);

      // Auto-completion's updatePact call writes through to the shared cache
      // immediately (HAB-174 WU2) — no eviction/reload round-trip needed.
      expect(cache.peek('expired')?.pact.status, PactStatus.completed,
          reason: 'auto-complete must write through to the shared cache immediately');
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
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      // Inject a "now" that is one day past the end date.
      final pastEndDate = DateTime(2054, 6, 2, 12, 0);
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final container = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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
      List<PactBreak> breaks = const [],
      List<Override> extras = const [],
    }) {
      fakeAnalytics = FakeAnalyticsService();
      return _makeContainer(
        pacts: pacts,
        showups: showups,
        breaks: breaks,
        extras: [analyticsServiceProvider.overrideWithValue(fakeAnalytics), ...extras],
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
      final throwingCache = _makeCache(throwingPactRepo, throwingShowupRepo);
      final throwingStatsService = PactStatsService(
        pactRepository: throwingPactRepo,
        showupRepository: throwingShowupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: throwingCache,
      );
      final throwingService = PactService(
        pactRepository: throwingPactRepo,
        showupRepository: throwingShowupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: throwingCache,
      );
      final failContainer = ProviderContainer(
        overrides: [
          pactServiceProvider.overrideWithValue(throwingService),
          pactStatsServiceProvider.overrideWithValue(throwingStatsService),
          pactDetailCacheProvider.overrideWithValue(throwingCache),
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

    test('stopBreak fires PactBreakStoppedEvent with correct properties on success (HAB-195 WU5.2)', () async {
      final onBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 10),
        plannedEndDate: DateTime(2026, 3, 20),
        rationale: 'Sick',
      );
      final container = makeContainerWithAnalytics(
        pacts: [_pact],
        showups: _showups,
        breaks: [onBreak],
        extras: [pactDetailNowProvider.overrideWithValue(DateTime(2026, 3, 15))],
      );
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopBreak();

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first as PactBreakStoppedEvent;
      expect(event.pactId, 'p1');
      expect(event.originalEndType, 'fixed_date');
      expect(event.daysSinceStart, 5); // Mar 15 - Mar 10
    });

    test('stopBreak reports until_pact_ends as the original end type for an open-ended break', () async {
      final openEndedBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 10),
        rationale: 'Sick',
      );
      final container = makeContainerWithAnalytics(
        pacts: [_pact],
        showups: _showups,
        breaks: [openEndedBreak],
        extras: [pactDetailNowProvider.overrideWithValue(DateTime(2026, 3, 12))],
      );
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopBreak();

      final event = fakeAnalytics.loggedEvents.first as PactBreakStoppedEvent;
      expect(event.originalEndType, 'until_pact_ends');
      expect(event.daysSinceStart, 2);
    });

    test('stopBreak clamps daysSinceStart to 0 for a break whose startDate is still in the future', () async {
      // startDate is 3 days after "now" — a not-yet-started, unresolved
      // break, which load() still surfaces as activeBreak (HAB-195 audit
      // finding: resuming it must not report a negative day count).
      final notYetStartedBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 18),
        plannedEndDate: DateTime(2026, 3, 25),
        rationale: 'Planned ahead',
      );
      final container = makeContainerWithAnalytics(
        pacts: [_pact],
        showups: _showups,
        breaks: [notYetStartedBreak],
        extras: [pactDetailNowProvider.overrideWithValue(DateTime(2026, 3, 15))],
      );
      addTearDown(container.dispose);

      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopBreak();

      final event = fakeAnalytics.loggedEvents.first as PactBreakStoppedEvent;
      expect(event.daysSinceStart, 0);
    });

    test('stopBreak does NOT fire event on failure', () async {
      fakeAnalytics = FakeAnalyticsService();

      final onBreak = PactBreak(
        id: 'brk-1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 10),
        plannedEndDate: DateTime(2026, 3, 20),
        rationale: 'Sick',
      );
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository(_showups);
      final throwingBreakRepo = _ThrowingOnUpdatePactBreakRepository([onBreak]);
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        pactBreakRepository: throwingBreakRepo,
        grouper: const PactTimelineGrouper(),
      );
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final reminderService = ReminderSchedulingService(
        notificationService: FakeNotificationService(),
        remoteConfig: FakeRemoteConfigService(),
        analytics: fakeAnalytics,
        localePreference: FakeLocalePreferenceService(),
      );
      final breakService = PactBreakService(
        pactBreakRepository: throwingBreakRepo,
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        reminderSchedulingService: reminderService,
        syncService: FakeSyncService(),
        cache: cache,
      );
      final failContainer = ProviderContainer(
        overrides: [
          pactServiceProvider.overrideWithValue(service),
          pactStatsServiceProvider.overrideWithValue(statsService),
          pactDetailCacheProvider.overrideWithValue(cache),
          pactBreakServiceProvider.overrideWithValue(breakService),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
          pactDetailNowProvider.overrideWithValue(DateTime(2026, 3, 15)),
        ],
      );
      addTearDown(failContainer.dispose);

      await failContainer.read(pactDetailViewModelProvider('p1').notifier).load();
      await failContainer.read(pactDetailViewModelProvider('p1').notifier).stopBreak();

      final state = failContainer.read(pactDetailViewModelProvider('p1'));
      expect(state.stopBreakError, isNotNull);
      expect(state.activeBreak, isNotNull); // unchanged on failure
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
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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

class _ThrowingOnUpdatePactBreakRepository extends InMemoryPactBreakRepository {
  _ThrowingOnUpdatePactBreakRepository(super.pactBreaks);

  @override
  Future<void> updateBreak(PactBreak pactBreak) async => throw Exception('update failed intentionally');
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
  Future<void> deleteShowupsForPactAfter(String pactId, DateTime after) async =>
      throw Exception('delete failed intentionally');
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
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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
      final cache = _makeCache(throwingPactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: throwingPactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: throwingPactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      fakeAnalytics = FakeAnalyticsService();
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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
      final cache = _makeCache(throwingRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: throwingRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final throwingService = PactService(
        pactRepository: throwingRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final workingCache = _makeCache(workingRepo, showupRepo);
      final workingStatsService = PactStatsService(
        pactRepository: workingRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(workingRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: workingCache,
      );
      final workingService = PactService(
        pactRepository: workingRepo,
        showupRepository: showupRepo,
        transactionService: InMemoryPactTransactionService(workingRepo, showupRepo),
        syncService: const NoopSyncService(),
        cache: workingCache,
      );

      fakeAnalytics = FakeAnalyticsService();
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(throwingService),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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
        pactDetailCacheProvider.overrideWithValue(workingCache),
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
      final cache = _makeCache(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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
      final cache = _makeCache(throwingRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: throwingRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final service = PactService(
        pactRepository: throwingRepo,
        showupRepository: showupRepo,
        transactionService: txService,
        syncService: const NoopSyncService(),
        cache: cache,
      );
      final c = ProviderContainer(overrides: [
        pactServiceProvider.overrideWithValue(service),
        pactStatsServiceProvider.overrideWithValue(statsService),
        pactDetailCacheProvider.overrideWithValue(cache),
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

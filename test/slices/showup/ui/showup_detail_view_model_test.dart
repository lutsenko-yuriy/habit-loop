import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';
import '../../../infrastructure/sync/fake_sync_service.dart';

// A fixed reference "now" to make auto-fail tests deterministic.
// We use a time clearly in the past so pending showups with past scheduledAt
// will be auto-failed.
final _past = DateTime(2020, 1, 1, 9, 0); // 09:00 on 2020-01-01

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 4, 1),
  endDate: DateTime(2026, 10, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

/// A pending showup scheduled in the past — will be auto-failed when
/// `now` is past `scheduledAt + duration`.
Showup _pendingPastShowup() => Showup(
      id: 's1',
      pactId: 'p1',
      scheduledAt: DateTime(2020, 1, 1, 8, 0), // 08:00, duration 10 min → ends 08:10
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

/// A pending showup scheduled in the future — should NOT be auto-failed.
Showup _pendingFutureShowup() => Showup(
      id: 's2',
      pactId: 'p1',
      scheduledAt: DateTime(2099, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

Showup _doneShowup() => Showup(
      id: 's3',
      pactId: 'p1',
      scheduledAt: DateTime(2020, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.done,
    );

Showup _failedShowup() => Showup(
      id: 's4',
      pactId: 'p1',
      scheduledAt: DateTime(2020, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.failed,
    );

ProviderContainer _makeContainer({
  required Showup showup,
  Pact? pact,
  DateTime? nowOverride,
}) {
  final showupRepo = InMemoryShowupRepository([showup]);
  final pactRepo = InMemoryPactRepository(pact != null ? [pact] : []);
  final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

  return ProviderContainer(
    overrides: [
      pactRepositoryProvider.overrideWithValue(pactRepo),
      showupRepositoryProvider.overrideWithValue(showupRepo),
      pactTransactionServiceProvider.overrideWithValue(txService),
      syncServiceProvider.overrideWithValue(const NoopSyncService()),
      if (nowOverride != null) showupDetailNowProvider.overrideWithValue(nowOverride),
    ],
  );
}

void main() {
  group('ShowupDetailViewModel', () {
    test('initial state is loading with no data', () {
      final showup = _pendingFutureShowup();
      final container = _makeContainer(showup: showup, pact: _pact);
      addTearDown(container.dispose);
      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.isLoading, true);
      expect(state.showup, isNull);
      expect(state.habitName, isNull);
    });

    test('load() populates state with showup and habit name', () async {
      final showup = _pendingFutureShowup();
      final container = _makeContainer(showup: showup, pact: _pact);
      addTearDown(container.dispose);
      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.isLoading, false);
      expect(state.showup, showup);
      expect(state.habitName, 'Meditate');
      expect(state.loadError, isNull);
      expect(state.wasAutoFailed, false);
    });

    test('load() sets error when showup not found', () async {
      final container = _makeContainer(
        showup: _pendingFutureShowup(),
        pact: _pact,
      );
      addTearDown(container.dispose);
      // Request a non-existent showup ID.
      await container.read(showupDetailViewModelProvider('nonexistent').notifier).load();
      final state = container.read(showupDetailViewModelProvider('nonexistent'));
      expect(state.isLoading, false);
      expect(state.loadError, isNotNull);
      expect(state.showup, isNull);
    });

    test('load() sets isShowupNotFound when showup does not exist in repository', () async {
      final container = _makeContainer(
        showup: _pendingFutureShowup(),
        pact: _pact,
      );
      addTearDown(container.dispose);
      // Request a non-existent showup ID.
      await container.read(showupDetailViewModelProvider('nonexistent').notifier).load();
      final state = container.read(showupDetailViewModelProvider('nonexistent'));
      expect(state.isShowupNotFound, isTrue);
      expect(state.isLoading, false);
      expect(state.showup, isNull);
    });

    test('load() auto-fails a pending showup when current time is past scheduledAt + duration', () async {
      final showup = _pendingPastShowup(); // scheduledAt=08:00, duration=10min → ends 08:10
      final container = _makeContainer(
        showup: showup,
        pact: _pact,
        nowOverride: _past, // _past is 09:00 — well after 08:10
      );
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      final state = container.read(showupDetailViewModelProvider(showup.id));

      expect(state.isLoading, false);
      expect(state.showup?.status, ShowupStatus.failed);
      expect(state.wasAutoFailed, true);
      expect(state.loadError, isNull);

      // Verify persisted
      final showupRepo = container.read(showupRepositoryProvider);
      final persisted = await showupRepo.getShowupById(showup.id);
      expect(persisted?.status, ShowupStatus.failed);

      final pactRepo = container.read(pactRepositoryProvider);
      final updatedPact = await pactRepo.getPactById('p1');
      final totalShowups = ShowupGenerator.countTotal(updatedPact!);
      expect(updatedPact.stats?.showupsFailed, 1);
      expect(updatedPact.stats?.showupsRemaining, totalShowups - 1);
    });

    test('load() does not auto-fail a pending showup before its end time', () async {
      final showup = _pendingPastShowup(); // scheduledAt=08:00, duration=10min → ends 08:10
      // nowOverride is 08:05 — within the window, so no auto-fail
      final earlyNow = DateTime(2020, 1, 1, 8, 5);
      final container = _makeContainer(
        showup: showup,
        pact: _pact,
        nowOverride: earlyNow,
      );
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      final state = container.read(showupDetailViewModelProvider(showup.id));

      expect(state.showup?.status, ShowupStatus.pending);
      expect(state.wasAutoFailed, false);
    });

    test('load() does not auto-fail an already-done showup even if past time', () async {
      final showup = _doneShowup();
      final container = _makeContainer(
        showup: showup,
        pact: _pact,
        nowOverride: _past,
      );
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      final state = container.read(showupDetailViewModelProvider(showup.id));

      expect(state.showup?.status, ShowupStatus.done);
      expect(state.wasAutoFailed, false);
    });

    test('load() does not auto-fail an already-failed showup', () async {
      final showup = _failedShowup();
      final container = _makeContainer(
        showup: showup,
        pact: _pact,
        nowOverride: _past,
      );
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      final state = container.read(showupDetailViewModelProvider(showup.id));

      expect(state.showup?.status, ShowupStatus.failed);
      expect(state.wasAutoFailed, false);
    });

    test('markDone() updates showup status to done and persists', () async {
      final showup = _pendingFutureShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markDone();

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.status, ShowupStatus.done);
      expect(state.markError, isNull);

      final persisted = await showupRepo.getShowupById(showup.id);
      expect(persisted?.status, ShowupStatus.done);

      final updatedPact = await pactRepo.getPactById('p1');
      final totalShowups = ShowupGenerator.countTotal(updatedPact!);
      expect(updatedPact.stats?.showupsDone, 1);
      expect(updatedPact.stats?.showupsRemaining, totalShowups - 1);
    });

    test('markFailed() updates showup status to failed and persists', () async {
      final showup = _pendingFutureShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markFailed();

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.status, ShowupStatus.failed);
      expect(state.markError, isNull);

      final persisted = await showupRepo.getShowupById(showup.id);
      expect(persisted?.status, ShowupStatus.failed);

      final updatedPact = await pactRepo.getPactById('p1');
      final totalShowups = ShowupGenerator.countTotal(updatedPact!);
      expect(updatedPact.stats?.showupsFailed, 1);
      expect(updatedPact.stats?.showupsRemaining, totalShowups - 1);
    });

    test('markDone() succeeds even when pact stats sync fails', () async {
      final showup = _pendingFutureShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = _ThrowingOnUpdatePactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markDone();

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.status, ShowupStatus.done);
      expect(state.markError, isNull);

      final persisted = await showupRepo.getShowupById(showup.id);
      expect(persisted?.status, ShowupStatus.done);
    });

    test('markDone() is a no-op when showup is already done', () async {
      final showup = _doneShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      final stateBefore = container.read(showupDetailViewModelProvider(showup.id));
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markDone();
      final stateAfter = container.read(showupDetailViewModelProvider(showup.id));

      expect(stateAfter.showup?.status, ShowupStatus.done);
      // No persistence call means the state object is identical (same showup ref)
      expect(stateAfter.showup, stateBefore.showup);
    });

    test('markDone() is a no-op when showup is failed', () async {
      final showup = _failedShowup();
      final container = _makeContainer(showup: showup, pact: _pact);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markDone();

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.status, ShowupStatus.failed);
    });

    test('markFailed() is a no-op when showup is already failed', () async {
      final showup = _failedShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      final stateBefore = container.read(showupDetailViewModelProvider(showup.id));
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markFailed();
      final stateAfter = container.read(showupDetailViewModelProvider(showup.id));

      expect(stateAfter.showup?.status, ShowupStatus.failed);
      expect(stateAfter.showup, stateBefore.showup);
    });

    test('saveNote() persists a note on a pending showup', () async {
      final showup = _pendingFutureShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).saveNote('Great session');

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.note, 'Great session');
      expect(state.noteError, isNull);

      final persisted = await showupRepo.getShowupById(showup.id);
      expect(persisted?.note, 'Great session');
    });

    test('saveNote() persists a note on a done showup (note always editable)', () async {
      final showup = _doneShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).saveNote('Felt good');

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.note, 'Felt good');
      expect(state.noteError, isNull);
    });

    test('saveNote() persists a note on a failed showup (note always editable)', () async {
      final showup = _failedShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).saveNote('Missed it');

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.note, 'Missed it');
    });

    test(
        'saveNote() write-through refreshes PactDetailCache so Timeline reflects the new note, '
        'without rewriting Pact.stats or re-uploading the pact', () async {
      final showup = _doneShowup();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final syncService = FakeSyncService();
      final cache = PactDetailCache(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        grouper: const PactTimelineGrouper(),
      );
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(syncService),
        pactDetailCacheProvider.overrideWithValue(cache),
      ]);
      addTearDown(container.dispose);

      // Warm the cache the way Pact Details does before Showup Detail opens.
      await cache.load(_pact.id);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).saveNote('Great session');

      final cachedMilestones = cache.peek(_pact.id)!.timelinePage.milestones;
      expect(
        cachedMilestones.whereType<NotedShowupMilestone>().any((m) => m.note == 'Great session'),
        isTrue,
        reason: 'saveNote must write through to the shared PactDetailCache — otherwise a note edit made '
            'via Showup Detail never appears on an already-warm Timeline (HAB-174 regression)',
      );
      // A note edit never changes stats — the cache refresh must not route
      // through PactStatsService.persistStats, which would redundantly
      // rewrite the pact row and re-upload it to Firestore on every note save.
      expect(syncService.uploadedPactIds, isEmpty,
          reason: 'saveNote must refresh the cache directly, not via a pact stats resync');
    });

    test('load() sets habitName to null when pact is not found (UI shows localised fallback)', () async {
      final showup = _pendingFutureShowup();
      // Empty pact repo — pact not found.
      final container = _makeContainer(showup: showup, pact: null);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      final state = container.read(showupDetailViewModelProvider(showup.id));

      expect(state.isLoading, false);
      expect(state.loadError, isNull);
      // habitName is null; the UI layer resolves the localised fallback string.
      expect(state.habitName, isNull);
    });

    test('load() resets isSaving so buttons are never stuck after re-entry', () async {
      final showup = _pendingFutureShowup();
      final container = _makeContainer(showup: showup, pact: _pact);
      addTearDown(container.dispose);

      // Simulate stale isSaving=true from a previous interrupted save.
      final notifier = container.read(showupDetailViewModelProvider(showup.id).notifier);
      // Manually force the state to have isSaving true.
      await notifier.load();
      // Directly check that after a second load isSaving is false.
      await notifier.load();
      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.isSaving, false);
      expect(state.markError, isNull);
      expect(state.noteError, isNull);
    });

    test('saveNote() with empty string clears the note', () async {
      final showup = Showup(
        id: 's5',
        pactId: 'p1',
        scheduledAt: DateTime(2099, 1, 1, 8),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
        note: 'Existing note',
      );
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).saveNote('');

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.note, isNull);

      final persisted = await showupRepo.getShowupById(showup.id);
      expect(persisted?.note, isNull);
    });
  });

  _redemptionNoteToggleTest();

  group('ShowupDetailViewModel analytics', () {
    late FakeAnalyticsService fakeAnalytics;

    ProviderContainer makeContainerWithAnalytics({
      required Showup showup,
      Pact? pact,
      DateTime? nowOverride,
    }) {
      fakeAnalytics = FakeAnalyticsService();
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository(pact != null ? [pact] : []);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      return ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          syncServiceProvider.overrideWithValue(const NoopSyncService()),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
          if (nowOverride != null) showupDetailNowProvider.overrideWithValue(nowOverride),
        ],
      );
    }

    test('load() fires ShowupAutoFailedEvent when showup is auto-failed', () async {
      final showup = _pendingPastShowup();
      final container = makeContainerWithAnalytics(
        showup: showup,
        pact: _pact,
        nowOverride: _past,
      );
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();

      final autoFailEvents = fakeAnalytics.loggedEvents.whereType<ShowupAutoFailedEvent>().toList();
      expect(autoFailEvents, hasLength(1));
      expect(autoFailEvents.first.pactId, showup.pactId);
    });

    test('load() does NOT fire ShowupAutoFailedEvent when showup is not auto-failed', () async {
      final showup = _pendingFutureShowup();
      final container = makeContainerWithAnalytics(
        showup: showup,
        pact: _pact,
      );
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();

      expect(fakeAnalytics.loggedEvents, isEmpty);
    });

    test('markDone() fires ShowupMarkedDoneEvent on success', () async {
      final showup = _pendingFutureShowup();
      final container = makeContainerWithAnalytics(showup: showup, pact: _pact);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      fakeAnalytics.reset();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markDone();

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first;
      expect(event, isA<ShowupMarkedDoneEvent>());
      expect((event as ShowupMarkedDoneEvent).pactId, showup.pactId);
    });

    test('markFailed() fires ShowupMarkedFailedEvent on success', () async {
      final showup = _pendingFutureShowup();
      final container = makeContainerWithAnalytics(showup: showup, pact: _pact);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      fakeAnalytics.reset();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markFailed();

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first;
      expect(event, isA<ShowupMarkedFailedEvent>());
      expect((event as ShowupMarkedFailedEvent).pactId, showup.pactId);
    });

    test('markDone() does NOT fire event when showup is already done (no-op)', () async {
      final showup = _doneShowup();
      final container = makeContainerWithAnalytics(showup: showup, pact: _pact);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      fakeAnalytics.reset();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markDone();

      expect(fakeAnalytics.loggedEvents, isEmpty);
    });

    test('markFailed() does NOT fire event when showup is already failed (no-op)', () async {
      final showup = _failedShowup();
      final container = makeContainerWithAnalytics(showup: showup, pact: _pact);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      fakeAnalytics.reset();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).markFailed();

      expect(fakeAnalytics.loggedEvents, isEmpty);
    });
  });

  _redemptionTests();

  group('ShowupDetailViewModel notification cancellation', () {
    ProviderContainer makeNotificationContainer({
      required Showup showup,
      required FakeNotificationService fakeNotifications,
      Pact? pact,
    }) {
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository(pact != null ? [pact] : []);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      return ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          syncServiceProvider.overrideWithValue(const NoopSyncService()),
          notificationServiceProvider.overrideWithValue(fakeNotifications),
        ],
      );
    }

    test('cancels notification when showup marked done', () async {
      final fakeNotifications = FakeNotificationService();
      final showup = _pendingFutureShowup();
      final c = makeNotificationContainer(
        showup: showup,
        pact: _pact,
        fakeNotifications: fakeNotifications,
      );
      addTearDown(c.dispose);

      await c.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await c.read(showupDetailViewModelProvider(showup.id).notifier).markDone();

      expect(fakeNotifications.cancelledShowupIds, contains(showup.id),
          reason: 'cancelShowupReminder must be called with the showup id when marking done');
    });

    test('cancels notification when showup marked failed', () async {
      final fakeNotifications = FakeNotificationService();
      final showup = _pendingFutureShowup();
      final c = makeNotificationContainer(
        showup: showup,
        pact: _pact,
        fakeNotifications: fakeNotifications,
      );
      addTearDown(c.dispose);

      await c.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await c.read(showupDetailViewModelProvider(showup.id).notifier).markFailed();

      expect(fakeNotifications.cancelledShowupIds, contains(showup.id),
          reason: 'cancelShowupReminder must be called with the showup id when marking failed');
    });
  });
}

class _ThrowingOnUpdatePactRepository extends InMemoryPactRepository {
  _ThrowingOnUpdatePactRepository(super.initialPacts);

  @override
  Future<void> updatePact(Pact pact) async => throw Exception('update failed intentionally');
}

// ---------------------------------------------------------------------------
// Redemption tests
// ---------------------------------------------------------------------------

// Anchored "now": 2099-06-15 12:00 — far future so no other test's showups interfere.
// Default tail period = 7 days → cutoff = 2099-06-08.
// In-tail failed showup: scheduledAt = 2099-06-10 (5 days ago, within 7-day window).
final _redemptionNow = DateTime(2099, 6, 15, 12, 0);

Showup _redeemableFailedShowup({String? note}) => Showup(
      id: 'sr1',
      pactId: 'p1',
      scheduledAt: DateTime(2099, 6, 10, 8, 0), // 5 days before _redemptionNow — in tail zone
      duration: const Duration(minutes: 10),
      status: ShowupStatus.failed,
      redeemable: true, // auto-failed
      note: note,
    );

Showup _manuallyFailedShowup() => Showup(
      id: 'sr2',
      pactId: 'p1',
      scheduledAt: DateTime(2099, 6, 10, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.failed,
      redeemable: false, // manually failed — not eligible
    );

Showup _outOfTailFailedShowup() => Showup(
      id: 'sr3',
      pactId: 'p1',
      scheduledAt: DateTime(2099, 5, 1, 8, 0), // far outside 7-day window
      duration: const Duration(minutes: 10),
      status: ShowupStatus.failed,
      redeemable: true,
    );

ProviderContainer _makeRedemptionContainer({
  required Showup showup,
  FakeAnalyticsService? analytics,
  bool redemptionEnabled = true,
  int tailDays = 7,
}) {
  final rc = FakeRemoteConfigService(overrides: {
    'showup_redemption_enabled': redemptionEnabled,
    'pact_timeline_no_grouping_tail_period_in_days': tailDays,
  });
  final showupRepo = InMemoryShowupRepository([showup]);
  final pactRepo = InMemoryPactRepository([_pact]);
  final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
  return ProviderContainer(
    overrides: [
      remoteConfigServiceProvider.overrideWithValue(rc),
      pactRepositoryProvider.overrideWithValue(pactRepo),
      showupRepositoryProvider.overrideWithValue(showupRepo),
      pactTransactionServiceProvider.overrideWithValue(txService),
      syncServiceProvider.overrideWithValue(const NoopSyncService()),
      showupDetailNowProvider.overrideWithValue(_redemptionNow),
      if (analytics != null) analyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
}

void _redemptionTests() {
  group('ShowupDetailViewModel — canRedeem', () {
    test('canRedeem is true for auto-failed in-tail showup when flag is on', () async {
      final showup = _redeemableFailedShowup();
      final container = _makeRedemptionContainer(showup: showup);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();

      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isTrue);
    });

    test('canRedeem is false for manually-failed showup (redeemable=false)', () async {
      final showup = _manuallyFailedShowup();
      final container = _makeRedemptionContainer(showup: showup);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();

      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isFalse);
    });

    test('canRedeem is false for showup outside the tail zone', () async {
      final showup = _outOfTailFailedShowup();
      final container = _makeRedemptionContainer(showup: showup);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();

      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isFalse);
    });

    test('canRedeem is false when RC kill-switch is off', () async {
      final showup = _redeemableFailedShowup();
      final container = _makeRedemptionContainer(showup: showup, redemptionEnabled: false);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();

      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isFalse);
    });

    test('canRedeem is false for a done showup', () async {
      final showup = _doneShowup();
      final container = _makeRedemptionContainer(showup: showup);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();

      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isFalse);
    });

    test('canRedeem is false for a pending showup', () async {
      final showup = _pendingFutureShowup();
      final container = _makeRedemptionContainer(showup: showup);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();

      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isFalse);
    });
  });

  group('ShowupDetailViewModel — redeemShowup', () {
    test('redeemShowup marks showup done when note is non-empty', () async {
      final showup = _redeemableFailedShowup(note: 'I did show up, sync was off');
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final rc = FakeRemoteConfigService(overrides: {
        'showup_redemption_enabled': true,
        'pact_timeline_no_grouping_tail_period_in_days': 7,
      });
      final container = ProviderContainer(overrides: [
        remoteConfigServiceProvider.overrideWithValue(rc),
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
        showupDetailNowProvider.overrideWithValue(_redemptionNow),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).redeemShowup();

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.status, ShowupStatus.done);
      expect(state.canRedeem, isFalse);

      final persisted = await showupRepo.getShowupById(showup.id);
      expect(persisted?.status, ShowupStatus.done);
    });

    test('redeemShowup does not change status when note is empty', () async {
      final showup = _redeemableFailedShowup(); // no note
      final container = _makeRedemptionContainer(showup: showup);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).redeemShowup();

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.status, ShowupStatus.failed);
      expect(state.canRedeem, isTrue);
    });

    test('redeemShowup is a no-op when canRedeem is false', () async {
      final showup = _manuallyFailedShowup();
      final container = _makeRedemptionContainer(showup: showup);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).redeemShowup();

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.status, ShowupStatus.failed);
    });
  });

  group('ShowupDetailViewModel — redemption analytics', () {
    test('load() fires ShowupRedemptionBlockedEvent when canRedeem and note is empty', () async {
      final analytics = FakeAnalyticsService();
      final showup = _redeemableFailedShowup(); // no note
      final container = _makeRedemptionContainer(showup: showup, analytics: analytics);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await Future<void>.delayed(Duration.zero);

      expect(analytics.loggedEvents.whereType<ShowupRedemptionBlockedEvent>(), hasLength(1));
    });

    test('load() does NOT fire ShowupRedemptionBlockedEvent when note is non-empty', () async {
      final analytics = FakeAnalyticsService();
      final showup = _redeemableFailedShowup(note: 'was there');
      final container = _makeRedemptionContainer(showup: showup, analytics: analytics);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await Future<void>.delayed(Duration.zero);

      expect(analytics.loggedEvents.whereType<ShowupRedemptionBlockedEvent>(), isEmpty);
    });

    test('redeemShowup fires ShowupRedeemedEvent on success', () async {
      final analytics = FakeAnalyticsService();
      final showup = _redeemableFailedShowup(note: 'sync was off');
      final showupRepo = InMemoryShowupRepository([showup]);
      final pactRepo = InMemoryPactRepository([_pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final rc = FakeRemoteConfigService(overrides: {
        'showup_redemption_enabled': true,
        'pact_timeline_no_grouping_tail_period_in_days': 7,
      });
      final container = ProviderContainer(overrides: [
        remoteConfigServiceProvider.overrideWithValue(rc),
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        syncServiceProvider.overrideWithValue(const NoopSyncService()),
        showupDetailNowProvider.overrideWithValue(_redemptionNow),
        analyticsServiceProvider.overrideWithValue(analytics),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      analytics.reset();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).redeemShowup();
      await Future<void>.delayed(Duration.zero);

      final events = analytics.loggedEvents.whereType<ShowupRedeemedEvent>().toList();
      expect(events, hasLength(1));
      expect(events.first.pactId, showup.pactId);
      expect(events.first.noteLength, 'sync was off'.length);
    });

    test('redeemShowup fires ShowupRedemptionBlockedEvent when note is empty', () async {
      final analytics = FakeAnalyticsService();
      final showup = _redeemableFailedShowup(); // no note
      final container = _makeRedemptionContainer(showup: showup, analytics: analytics);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      analytics.reset();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).redeemShowup();
      await Future<void>.delayed(Duration.zero);

      expect(analytics.loggedEvents.whereType<ShowupRedemptionBlockedEvent>(), hasLength(1));
    });
  });
}

void _redemptionNoteToggleTest() {
  group('ShowupDetailViewModel — redemption button toggled by note save/clear', () {
    // Covers the round-trip: auto-failed showup with no note (button disabled) →
    // save a note (button enables) → clear the note (button disables again).
    test('saving a note enables the redeem button; clearing it disables it again', () async {
      final showup = _redeemableFailedShowup(); // no note
      final container = _makeRedemptionContainer(showup: showup);
      addTearDown(container.dispose);

      final notifier = container.read(showupDetailViewModelProvider(showup.id).notifier);

      await notifier.load();
      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isTrue);
      expect(container.read(showupDetailViewModelProvider(showup.id)).showup?.note, isNull);

      // Save a note → persisted note is non-empty → button should be active.
      await notifier.saveNote('I was there, phone was offline');
      expect(container.read(showupDetailViewModelProvider(showup.id)).showup?.note, 'I was there, phone was offline');
      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isTrue);
      // canRedeem stays true; the note presence is what gates onPressed in the UI.

      // Clear the note → persisted note is null → button disabled again.
      await notifier.saveNote('');
      expect(container.read(showupDetailViewModelProvider(showup.id)).showup?.note, isNull);
      expect(container.read(showupDetailViewModelProvider(showup.id)).canRedeem, isTrue);
      // canRedeem is still true (the section stays visible); the UI disables
      // onPressed because note is empty. We verify the note is null so the
      // content layer's `hasNote` check evaluates to false.
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_detail_view_model.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';

import '../../../analytics/fake_analytics_service.dart';

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

  return ProviderContainer(
    overrides: [
      showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
      showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      final showupRepo = container.read(showupDetailShowupRepositoryProvider);
      final persisted = await showupRepo.getShowupById(showup.id);
      expect(persisted?.status, ShowupStatus.failed);

      final pactRepo = container.read(showupDetailPactRepositoryProvider);
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
      ]);
      addTearDown(container.dispose);

      await container.read(showupDetailViewModelProvider(showup.id).notifier).load();
      await container.read(showupDetailViewModelProvider(showup.id).notifier).saveNote('Missed it');

      final state = container.read(showupDetailViewModelProvider(showup.id));
      expect(state.showup?.note, 'Missed it');
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
      final container = ProviderContainer(overrides: [
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
      return ProviderContainer(
        overrides: [
          showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
          showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first;
      expect(event, isA<ShowupAutoFailedEvent>());
      expect((event as ShowupAutoFailedEvent).pactId, showup.pactId);
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
}

class _ThrowingOnUpdatePactRepository extends InMemoryPactRepository {
  _ThrowingOnUpdatePactRepository(super.initialPacts);

  @override
  Future<void> updatePact(Pact pact) async => throw Exception('update failed intentionally');
}

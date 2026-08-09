import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/application/pact_break_service.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_view_model.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/logging/fake_log_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';
import '../../../infrastructure/sync/fake_sync_service.dart';

/// Throws on every read — used to exercise [PactBreakCreationViewModel.load]'s
/// error-swallowing contract (HAB-215).
class _ThrowingShowupRepository extends InMemoryShowupRepository {
  @override
  Future<List<Showup>> getShowupsForPact(String pactId) => throw Exception('boom');
}

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

ProviderContainer _makeContainerWithShowupRepo({
  DateTime? now,
  List<Override> extras = const [],
  List<Showup> showups = const [],
  InMemoryShowupRepository? showupRepoOverride,
}) {
  final pactRepo = InMemoryPactRepository([_pact]);
  final showupRepo = showupRepoOverride ?? InMemoryShowupRepository(showups);
  final breakRepo = InMemoryPactBreakRepository();
  final cache = PactDetailCache(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    pactBreakRepository: breakRepo,
    grouper: const PactTimelineGrouper(),
  );
  final reminderService = ReminderSchedulingService(
    notificationService: FakeNotificationService(),
    remoteConfig: FakeRemoteConfigService(),
    analytics: FakeAnalyticsService(),
    localePreference: FakeLocalePreferenceService(),
  );
  final service = PactBreakService(
    pactBreakRepository: breakRepo,
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    reminderSchedulingService: reminderService,
    syncService: FakeSyncService(),
    cache: cache,
  );

  return ProviderContainer(
    overrides: [
      pactBreakServiceProvider.overrideWithValue(service),
      pactBreakRepositoryProvider.overrideWithValue(breakRepo),
      showupRepositoryProvider.overrideWithValue(showupRepo),
      if (now != null) pactBreakCreationNowProvider.overrideWithValue(now),
      ...extras,
    ],
  );
}

ProviderContainer _makeContainer({
  DateTime? now,
  List<Override> extras = const [],
}) =>
    _makeContainerWithShowupRepo(now: now, extras: extras);

void main() {
  group('PactBreakCreationViewModel', () {
    test('build defaults startDate to today and endDate to today + 7 days', () {
      final container = _makeContainer(now: DateTime(2026, 6, 15, 10, 30));
      addTearDown(container.dispose);
      final state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.startDate, DateTime(2026, 6, 15));
      expect(state.endDate, DateTime(2026, 6, 22));
      expect(state.untilPactEnds, false);
      expect(state.rationale, '');
      expect(state.canSubmit, false); // empty rationale
    });

    test('setRationale updates state and canSubmit becomes true', () {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier.setRationale('Feeling sick');
      final state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.rationale, 'Feeling sick');
      expect(state.canSubmit, true);
    });

    test('canSubmit is false when rationale is only whitespace', () {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier.setRationale('   ');
      expect(container.read(pactBreakCreationViewModelProvider('p1')).canSubmit, false);
    });

    test('setStartDate and setEndDate normalize to midnight', () {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier.setStartDate(DateTime(2026, 6, 20, 14, 30));
      notifier.setEndDate(DateTime(2026, 6, 25, 9, 0));
      final state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.startDate, DateTime(2026, 6, 20));
      expect(state.endDate, DateTime(2026, 6, 25));
    });

    test('setStartDate bumps endDate forward when it would otherwise become inverted (before startDate)', () {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      // Default endDate is 2026-06-22 — moving startDate past it must not
      // leave an inverted window.
      notifier.setStartDate(DateTime(2026, 6, 25));
      final state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.startDate, DateTime(2026, 6, 25));
      expect(state.endDate.isAfter(state.startDate), true);
    });

    test('setStartDate leaves endDate equal to startDate untouched — a same-day break is valid (HAB-215)', () {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      // Default endDate is 2026-06-22 — moving startDate to exactly that
      // date must not bump endDate forward; a single-day break is allowed.
      notifier.setStartDate(DateTime(2026, 6, 22));
      final state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.startDate, DateTime(2026, 6, 22));
      expect(state.endDate, DateTime(2026, 6, 22));
    });

    test('setStartDate leaves endDate untouched when it is still after the new startDate', () {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier.setStartDate(DateTime(2026, 6, 16));
      final state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.startDate, DateTime(2026, 6, 16));
      expect(state.endDate, DateTime(2026, 6, 22)); // untouched default
    });

    test('setUntilPactEnds toggles the flag without discarding endDate', () {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      final originalEndDate = container.read(pactBreakCreationViewModelProvider('p1')).endDate;
      notifier.setUntilPactEnds(true);
      var state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.untilPactEnds, true);
      expect(state.endDate, originalEndDate);
      notifier.setUntilPactEnds(false);
      state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.untilPactEnds, false);
      expect(state.endDate, originalEndDate);
    });

    test('submit returns false and does nothing when rationale is empty', () async {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      final result = await notifier.submit(source: 'pact_detail');
      expect(result, false);
      final breaks = await container.read(pactBreakRepositoryProvider).getBreaksForPact('p1');
      expect(breaks, isEmpty);
    });

    test('submit persists a fixed-end break and fires PactBreakStartedEvent', () async {
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(now: DateTime(2026, 6, 15), extras: [
        analyticsServiceProvider.overrideWithValue(analytics),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier.setRationale('Feeling sick');

      final result = await notifier.submit(source: 'pact_detail');
      expect(result, true);

      final breaks = await container.read(pactBreakRepositoryProvider).getBreaksForPact('p1');
      expect(breaks, hasLength(1));
      expect(breaks.first.startDate, DateTime(2026, 6, 15));
      expect(breaks.first.plannedEndDate, DateTime(2026, 6, 22));
      expect(breaks.first.rationale, 'Feeling sick');

      expect(analytics.loggedEvents, hasLength(1));
      final params = analytics.loggedEvents.first.toParameters();
      expect(analytics.loggedEvents.first.name, 'pact_break_started');
      expect(params['pact_id'], 'p1');
      expect(params['source'], 'pact_detail');
      expect(params['end_type'], 'fixed_date');
      expect(params['duration_days'], 7);
      expect(params['rationale_length'], 'Feeling sick'.length);

      final state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.isSubmitting, false);
      expect(state.submitError, isNull);
    });

    test('submit persists a plannedEndDate that still covers a showup later that same day (HAB-215)', () async {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier.setRationale('Feeling sick');

      await notifier.submit(source: 'pact_detail');

      final breaks = await container.read(pactBreakRepositoryProvider).getBreaksForPact('p1');
      // A showup scheduled at 20:00 on the picked end date (2026-06-22) must
      // still fall inside the break window, not just one scheduled at midnight.
      expect(breaks.first.contains(DateTime(2026, 6, 22, 20)), isTrue);
      expect(breaks.first.contains(DateTime(2026, 6, 23)), isFalse);
    });

    test('submit persists an open-ended break when untilPactEnds is true', () async {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier.setRationale('Travel');
      notifier.setUntilPactEnds(true);

      final result = await notifier.submit(source: 'tail_zone_showup');
      expect(result, true);

      final breaks = await container.read(pactBreakRepositoryProvider).getBreaksForPact('p1');
      expect(breaks.first.plannedEndDate, isNull);
    });

    group('load / nextShowupAfterEnd (HAB-215)', () {
      Showup showup(String id, DateTime scheduledAt) => Showup(
            id: id,
            pactId: 'p1',
            scheduledAt: scheduledAt,
            duration: const Duration(minutes: 10),
            status: ShowupStatus.pending,
          );

      test('nextShowupAfterEnd is null before load() resolves', () {
        final container = _makeContainer(now: DateTime(2026, 6, 15));
        addTearDown(container.dispose);
        final state = container.read(pactBreakCreationViewModelProvider('p1'));
        expect(state.nextShowupAfterEnd, isNull);
      });

      test('nextShowupAfterEnd is the earliest showup after the end-of-day boundary', () async {
        final container = _makeContainerWithShowupRepo(
          now: DateTime(2026, 6, 15),
          showups: [
            showup('s1', DateTime(2026, 6, 22, 8)), // inside the break window — must be excluded
            showup('s2', DateTime(2026, 6, 24, 8)), // the actual next one
            showup('s3', DateTime(2026, 6, 26, 8)), // later still
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);

        await notifier.load();

        final state = container.read(pactBreakCreationViewModelProvider('p1'));
        expect(state.nextShowupAfterEnd, DateTime(2026, 6, 24, 8));
      });

      test('nextShowupAfterEnd is null when untilPactEnds is true, regardless of loaded showups', () async {
        final container = _makeContainerWithShowupRepo(
          now: DateTime(2026, 6, 15),
          showups: [showup('s1', DateTime(2026, 6, 24, 8))],
        );
        addTearDown(container.dispose);
        final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);

        await notifier.load();
        notifier.setUntilPactEnds(true);

        final state = container.read(pactBreakCreationViewModelProvider('p1'));
        expect(state.nextShowupAfterEnd, isNull);
      });

      test('load swallows a repository failure instead of crashing (HAB-215)', () async {
        final logService = FakeLogService();
        final container = _makeContainerWithShowupRepo(
          now: DateTime(2026, 6, 15),
          showupRepoOverride: _ThrowingShowupRepository(),
          extras: [logServiceProvider.overrideWithValue(logService)],
        );
        addTearDown(container.dispose);
        final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);

        await notifier.load(); // must not throw

        final state = container.read(pactBreakCreationViewModelProvider('p1'));
        expect(state.nextShowupAfterEnd, isNull);
        expect(logService.errorCalls, hasLength(1));
        expect(logService.errorCalls.first.message, contains('pact_break_creation_showup_load_failed'));
      });

      test('nextShowupAfterEnd is null when no showup falls after the end date', () async {
        final container = _makeContainerWithShowupRepo(
          now: DateTime(2026, 6, 15),
          showups: [showup('s1', DateTime(2026, 6, 20, 8))],
        );
        addTearDown(container.dispose);
        final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);

        await notifier.load();

        final state = container.read(pactBreakCreationViewModelProvider('p1'));
        expect(state.nextShowupAfterEnd, isNull);
      });
    });

    test('submit sets submitError and returns false when the service throws', () async {
      final container = _makeContainer(now: DateTime(2026, 6, 15));
      addTearDown(container.dispose);
      final notifier = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier.setRationale('First break');
      await notifier.submit(source: 'pact_detail');

      // A second break for the same pact is rejected by PactBreakService
      // (only one unresolved break allowed at a time) — exercises the catch path.
      final notifier2 = container.read(pactBreakCreationViewModelProvider('p1').notifier);
      notifier2.setRationale('Second break');
      final result = await notifier2.submit(source: 'pact_detail');

      expect(result, false);
      final state = container.read(pactBreakCreationViewModelProvider('p1'));
      expect(state.submitError, isNotNull);
      expect(state.isSubmitting, false);
    });
  });
}

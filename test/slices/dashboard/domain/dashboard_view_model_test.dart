import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/notifications/fake_notification_service.dart';

/// Wraps [InMemoryShowupRepository] and counts calls to [getShowupsForPact].
class _CountingShowupRepository extends InMemoryShowupRepository {
  _CountingShowupRepository([super.initialShowups]);

  int getShowupsForPactCallCount = 0;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    getShowupsForPactCallCount++;
    return super.getShowupsForPact(pactId);
  }
}

// Helper to build a daily-schedule pact starting on [startDate].
Pact _dailyPact({
  required String id,
  required DateTime startDate,
  DateTime? endDate,
  PactStatus status = PactStatus.active,
}) {
  return Pact(
    id: id,
    habitName: 'Habit $id',
    startDate: startDate,
    endDate: endDate ?? DateTime(startDate.year, startDate.month + 6, startDate.day),
    showupDuration: const Duration(minutes: 10),
    schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
    status: status,
  );
}

void main() {
  late ProviderContainer container;

  final today = DateTime(2026, 3, 29);

  ProviderContainer createContainer({
    List<Pact> pacts = const [],
    List<Showup> showups = const [],
  }) {
    final pactRepo = InMemoryPactRepository(pacts);
    final showupRepo = InMemoryShowupRepository(showups);
    final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
    return ProviderContainer(
      overrides: [
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),
        todayProvider.overrideWithValue(today),
      ],
    );
  }

  group('DashboardViewModel', () {
    test('initial state is loading', () {
      container = createContainer();

      final state = container.read(dashboardViewModelProvider);

      expect(state.isLoading, isTrue);
    });

    test('loads 7 calendar days centered on today', () async {
      container = createContainer();

      // Wait for async load
      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.isLoading, isFalse);
      expect(state.calendarDays, hasLength(7));
      expect(state.calendarDays[0].date, DateTime(2026, 3, 26));
      expect(state.calendarDays[3].date, today);
      expect(state.calendarDays[6].date, DateTime(2026, 4, 1));
    });

    test('today is selected by default (index 3)', () async {
      container = createContainer();

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.selectedDayIndex, 3);
    });

    test('empty state — no showups when no pacts', () async {
      // No pacts at all → no showups generated → selected day is empty
      container = createContainer();

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.selectedDayShowups, isEmpty);
    });

    test('loads showups into correct calendar days', () async {
      final showupToday = Showup(
        id: '1',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 29, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );
      final showupYesterday = Showup(
        id: '2',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 28, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
      );

      container = createContainer(
        pacts: [
          Pact(
            id: 'pact-1',
            habitName: 'Meditate',
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 9, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
          ),
        ],
        showups: [showupToday, showupYesterday],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      // Today is index 3 (pact started 28 days ago → offset 3)
      // The pre-seeded showup AND the lazily-generated one for today both appear.
      expect(state.calendarDays[3].showups, contains(showupToday));
      // Yesterday is index 2; generation window starts at today, so the
      // pre-seeded yesterday showup is the only one there.
      expect(state.calendarDays[2].showups, [showupYesterday]);
    });

    test('selectDay updates selected day index', () async {
      final showupMar27 = Showup(
        id: '1',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 27, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
      );

      container = createContainer(
        pacts: [
          Pact(
            id: 'pact-1',
            habitName: 'Meditate',
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 9, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
          ),
        ],
        showups: [showupMar27],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      container.read(dashboardViewModelProvider.notifier).selectDay(1);
      final state = container.read(dashboardViewModelProvider);

      expect(state.selectedDayIndex, 1);
      expect(state.selectedDayShowups, [showupMar27]);
    });

    test('hasActivePacts is false when no active pacts', () async {
      container = createContainer();

      await container.read(dashboardViewModelProvider.notifier).load();
      final hasActive = await container.read(hasActivePactsProvider.future);

      expect(hasActive, isFalse);
    });

    test('hasActivePacts is true when active pacts exist', () async {
      container = createContainer(pacts: [
        Pact(
          id: '1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        ),
      ]);

      final hasActive = await container.read(hasActivePactsProvider.future);

      expect(hasActive, isTrue);
    });
  });

  // today = DateTime(2026, 3, 29)
  //
  // todayIndex formula: min(daysSinceOldestPact, 3)
  //   where daysSinceOldestPact = today.difference(oldestStartDate).inDays
  //
  // ALL pacts (active, stopped, completed) contribute to finding the oldest
  // start date so that deleting or stopping a pact never shifts the strip.
  //
  //   Day 1 (today == oldestStartDate)        → todayIndex = 0
  //   Day 2 (today == oldestStartDate + 1)    → todayIndex = 1
  //   Day 3 (today == oldestStartDate + 2)    → todayIndex = 2
  //   Day 4+ (today >= oldestStartDate + 3)   → todayIndex = 3
  group('todayIndex — calendar strip offset', () {
    test('todayIndex is 3 when no pacts exist', () async {
      container = createContainer();

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('todayIndex is 3 when oldest pact started 10+ days before today', () async {
      // pact started 10 days before today → daysSince = 10, clamped to 3
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 19))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('todayIndex is 0 when oldest pact started today (day 1)', () async {
      // daysSince = 0 → todayIndex = min(0, 3) = 0
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: today)],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 0);
    });

    test('todayIndex is 1 when oldest pact started yesterday (day 2)', () async {
      // daysSince = 1 → todayIndex = min(1, 3) = 1
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 28))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 1);
    });

    test('todayIndex is 2 when oldest pact started 2 days ago (day 3)', () async {
      // daysSince = 2 → todayIndex = min(2, 3) = 2
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 27))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 2);
    });

    test('todayIndex is 3 when oldest pact started 3 days ago (day 4)', () async {
      // daysSince = 3 → todayIndex = min(3, 3) = 3
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 26))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('todayIndex considers ALL pacts regardless of status', () async {
      // Stopped pact started today (daysSince=0) and active pact started 2
      // days ago (daysSince=2).  Oldest = 2 days ago → todayIndex = 2.
      container = createContainer(
        pacts: [
          _dailyPact(id: 'p1', startDate: today, status: PactStatus.stopped),
          _dailyPact(id: 'p2', startDate: DateTime(2026, 3, 27)),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 2);
    });

    test('todayIndex is 0 when stopped pact is the only one and started today', () async {
      // daysSince = 0 → todayIndex = 0.  Stopping the pact must not shift
      // the strip back to the centred layout.
      container = createContainer(
        pacts: [
          _dailyPact(id: 'p1', startDate: today, status: PactStatus.stopped),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 0);
    });

    test('todayIndex uses oldest start date across mixed-status pacts', () async {
      // Active pact started today (daysSince=0); stopped pact started 2 days
      // ago (daysSince=2).  Oldest = 2 days ago → todayIndex = 2.
      container = createContainer(
        pacts: [
          _dailyPact(id: 'p1', startDate: today),
          _dailyPact(id: 'p2', startDate: DateTime(2026, 3, 27), status: PactStatus.stopped),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 2);
    });

    test('calendar strip is centred on today (todayIndex = 3) for day 4+', () async {
      // pact started 3 days ago → todayIndex = 3 → strip[0] = today - 3
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 26))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.calendarDays, hasLength(7));
      expect(state.calendarDays[0].date, DateTime(2026, 3, 26)); // today - 3
      expect(state.calendarDays[3].date, today); // today at index 3
    });

    test('calendar strip starts at today when todayIndex = 0 (day 1)', () async {
      // pact started today → todayIndex = 0 → strip[0] = today
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: today)],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.calendarDays, hasLength(7));
      expect(state.calendarDays[0].date, today);
    });

    test('calendar strip on day 2: strip[0] = today-1, today at index 1', () async {
      // pact started yesterday → todayIndex = 1 → strip[0] = today - 1
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 28))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.calendarDays, hasLength(7));
      expect(state.calendarDays[0].date, DateTime(2026, 3, 28)); // today - 1
      expect(state.calendarDays[1].date, today); // today at index 1
    });

    test('calendar strip on day 3: strip[0] = today-2, today at index 2', () async {
      // pact started 2 days ago → todayIndex = 2 → strip[0] = today - 2
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 27))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.calendarDays, hasLength(7));
      expect(state.calendarDays[0].date, DateTime(2026, 3, 27)); // today - 2
      expect(state.calendarDays[2].date, today); // today at index 2
    });

    test('selectedDayIndex defaults to todayIndex after load', () async {
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: today)],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.selectedDayIndex, state.todayIndex);
    });
  });

  group('lazy showup generation on load', () {
    test('generates showups for active pacts into repository on load', () async {
      final showupRepo = InMemoryShowupRepository();
      final pact = _dailyPact(id: 'p1', startDate: today);
      final pactRepo = InMemoryPactRepository([pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          todayProvider.overrideWithValue(today),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();

      // Repository should now contain showups for the window [today, today+10]
      final generated = await showupRepo.getShowupsForDateRange(
        today,
        today.add(const Duration(days: 10)),
      );
      expect(generated, isNotEmpty);
    });

    test('generated showups appear on calendar after load', () async {
      // Repo starts empty; pact starts today → load must generate + display
      final showupRepo = InMemoryShowupRepository();
      final pact = _dailyPact(id: 'p1', startDate: today);
      final pactRepo = InMemoryPactRepository([pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          todayProvider.overrideWithValue(today),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      // todayIndex = 0 (pact started today), so calendarDays[0] = today
      final todayShowups = state.calendarDays[0].showups;
      expect(todayShowups, isNotEmpty);
    });

    test('does not duplicate showups on repeated load calls', () async {
      final showupRepo = InMemoryShowupRepository();
      final pact = _dailyPact(id: 'p1', startDate: today);
      final pactRepo = InMemoryPactRepository([pact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          todayProvider.overrideWithValue(today),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      await container.read(dashboardViewModelProvider.notifier).load();

      final all = await showupRepo.getShowupsForPact('p1');
      final ids = all.map((s) => s.id).toSet();
      // Every id must be unique (no duplicates)
      expect(ids.length, all.length);
    });

    test('does not generate showups for stopped pacts', () async {
      final showupRepo = InMemoryShowupRepository();
      final stoppedPact = _dailyPact(
        id: 'p1',
        startDate: today,
        status: PactStatus.stopped,
      );
      final pactRepo = InMemoryPactRepository([stoppedPact]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          todayProvider.overrideWithValue(today),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();

      final all = await showupRepo.getShowupsForPact('p1');
      expect(all, isEmpty);
    });
  });

  group('lazy stats cache on load', () {
    test('currentStats is a cache hit after load() — second call avoids DB', () async {
      final pact = _dailyPact(id: 'p1', startDate: today);
      // Pre-seed a done showup so the cached stats have showupsDone=1.
      final doneShowup = Showup(
        id: 's1',
        pactId: 'p1',
        scheduledAt: DateTime(today.year, today.month, today.day - 1, 7),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
      );
      final pactRepo = InMemoryPactRepository([pact]);
      final showupRepo = _CountingShowupRepository([doneShowup]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          pactStatsServiceProvider.overrideWithValue(statsService),
          todayProvider.overrideWithValue(today),
        ],
      );
      addTearDown(container.dispose);

      await container.read(dashboardViewModelProvider.notifier).load();

      // First call to currentStats after dashboard load — lazy miss → DB hit,
      // result cached.
      final statsFirst = await statsService.currentStats(pact: pact, showups: []);
      final callsAfterFirst = showupRepo.getShowupsForPactCallCount;

      // Second call — must be a cache hit (no additional DB round-trip).
      final statsSecond = await statsService.currentStats(pact: pact, showups: []);

      expect(showupRepo.getShowupsForPactCallCount, callsAfterFirst,
          reason: 'Second call to currentStats must be a cache hit');
      expect(statsFirst.showupsDone, statsSecond.showupsDone);
      // The cached stats reflect the done showup.
      expect(statsSecond.showupsDone, 1);
    });

    test('DashboardViewModel does not call preWarmCache — cache is populated lazily', () async {
      // This test verifies that the dashboard itself does not try to pre-warm
      // anything; the cache is populated on first currentStats call per pact.
      final stoppedPact = _dailyPact(id: 'p1', startDate: today, status: PactStatus.stopped);
      final activePact = _dailyPact(id: 'p2', startDate: today);
      final doneShowup = Showup(
        id: 's2',
        pactId: 'p2',
        scheduledAt: DateTime(today.year, today.month, today.day - 1, 7),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
      );
      final pactRepo = InMemoryPactRepository([stoppedPact, activePact]);
      final showupRepo = _CountingShowupRepository([doneShowup]);
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final statsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        transactionService: txService,
      );

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          pactStatsServiceProvider.overrideWithValue(statsService),
          todayProvider.overrideWithValue(today),
        ],
      );
      addTearDown(container.dispose);

      await container.read(dashboardViewModelProvider.notifier).load();

      // After load, the stats cache is cold — first call lazily loads from DB.
      final callsBeforeCacheAccess = showupRepo.getShowupsForPactCallCount;
      final activeStats = await statsService.currentStats(pact: activePact, showups: []);

      // First lazy access hits DB.
      expect(showupRepo.getShowupsForPactCallCount, greaterThan(callsBeforeCacheAccess));
      expect(activeStats.showupsDone, 1);

      // Second access is a cache hit.
      final callsAfterFirstAccess = showupRepo.getShowupsForPactCallCount;
      await statsService.currentStats(pact: activePact, showups: []);
      expect(showupRepo.getShowupsForPactCallCount, callsAfterFirstAccess);
    });
  });

  group('notification scheduling on dashboard load', () {
    test('schedules reminders for newly generated showups when pact has reminderOffset', () async {
      final fakeNotifications = FakeNotificationService();
      final pact = Pact(
        id: 'p-notif',
        habitName: 'Jog',
        startDate: today,
        endDate: DateTime(today.year, today.month + 6, today.day),
        showupDuration: const Duration(minutes: 20),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
        reminderOffset: const Duration(minutes: 15),
      );
      final pactRepo = InMemoryPactRepository([pact]);
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

      final c = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          todayProvider.overrideWithValue(today),
          notificationServiceProvider.overrideWithValue(fakeNotifications),
        ],
      );
      addTearDown(c.dispose);

      await c.read(dashboardViewModelProvider.notifier).load();

      expect(fakeNotifications.scheduledReminders, isNotEmpty,
          reason: 'Dashboard must schedule reminders for newly generated showups when reminderOffset is set');
    });

    test('skips scheduling when pact has no reminderOffset', () async {
      final fakeNotifications = FakeNotificationService();
      final pact = Pact(
        id: 'p-no-notif',
        habitName: 'Jog',
        startDate: today,
        endDate: DateTime(today.year, today.month + 6, today.day),
        showupDuration: const Duration(minutes: 20),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      final pactRepo = InMemoryPactRepository([pact]);
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

      final c = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          todayProvider.overrideWithValue(today),
          notificationServiceProvider.overrideWithValue(fakeNotifications),
        ],
      );
      addTearDown(c.dispose);

      await c.read(dashboardViewModelProvider.notifier).load();

      expect(fakeNotifications.scheduledReminders, isEmpty,
          reason: 'Dashboard must NOT schedule reminders when pact has no reminderOffset');
    });
  });
}

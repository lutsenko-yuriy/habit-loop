import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

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
    return ProviderContainer(
      overrides: [
        pactRepositoryProvider
            .overrideWithValue(InMemoryPactRepository(pacts)),
        showupRepositoryProvider
            .overrideWithValue(InMemoryShowupRepository(showups)),
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
      final hasActive =
          await container.read(hasActivePactsProvider.future);

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

      final hasActive =
          await container.read(hasActivePactsProvider.future);

      expect(hasActive, isTrue);
    });
  });

  // today = DateTime(2026, 3, 29)
  //
  // New offset rules (simplified):
  //   - Query ALL pacts (regardless of status) to find the oldest start date.
  //   - If today == that oldest start date → todayIndex = 0.
  //   - Otherwise → todayIndex = 3.
  //   - No intermediate values (1, 2) — the strip only shifts on the very first
  //     day the user created their first pact ever.
  group('todayIndex — calendar strip offset', () {
    test('todayIndex is 3 when no pacts exist', () async {
      container = createContainer();

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('todayIndex is 3 when oldest pact started before today', () async {
      // pact started 10 days before today → not the same day → todayIndex = 3
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 19))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('todayIndex is 0 when oldest pact started today', () async {
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: today)],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 0);
    });

    test('todayIndex is 3 when oldest pact started yesterday', () async {
      // Started yesterday — not today → todayIndex = 3 (centered)
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 28))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('todayIndex is 3 when oldest pact started 2 days ago', () async {
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 27))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('todayIndex considers ALL pacts regardless of status', () async {
      // Stopped pact started today and active pact started 2 days ago.
      // With all-pacts logic: oldest = 2 days ago (not today) → todayIndex = 3.
      container = createContainer(
        pacts: [
          _dailyPact(id: 'p1', startDate: today, status: PactStatus.stopped),
          _dailyPact(id: 'p2', startDate: DateTime(2026, 3, 27)),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('todayIndex is 0 when stopped pact is the only one and started today', () async {
      // A stopped pact that was created today → oldest start = today → todayIndex = 0.
      // Deleting/stopping a pact must not shift the strip back to centered layout.
      container = createContainer(
        pacts: [
          _dailyPact(id: 'p1', startDate: today, status: PactStatus.stopped),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 0);
    });

    test('todayIndex uses oldest across mixed-status pacts', () async {
      // Active pact started today (would give 0); stopped pact started 2 days
      // ago (oldest, not today) → todayIndex = 3.
      container = createContainer(
        pacts: [
          _dailyPact(id: 'p1', startDate: today),
          _dailyPact(id: 'p2', startDate: DateTime(2026, 3, 27), status: PactStatus.stopped),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.todayIndex, 3);
    });

    test('calendar strip is centered on today (todayIndex = 3) by default', () async {
      // pact started yesterday → todayIndex = 3 → strip[0] = today - 3
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: DateTime(2026, 3, 28))],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.calendarDays, hasLength(7));
      expect(state.calendarDays[0].date, DateTime(2026, 3, 26)); // today - 3
      expect(state.calendarDays[3].date, today);                  // today at index 3
    });

    test('calendar strip starts at today when todayIndex = 0', () async {
      // pact started today → todayIndex = 0 → strip[0] = today
      container = createContainer(
        pacts: [_dailyPact(id: 'p1', startDate: today)],
      );

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      expect(state.calendarDays, hasLength(7));
      expect(state.calendarDays[0].date, today);
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

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(InMemoryPactRepository([pact])),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          todayProvider.overrideWithValue(today),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();

      // Repository should now contain showups for the window [today, today+7]
      final generated = await showupRepo.getShowupsForDateRange(
        today,
        DateTime(today.year, today.month, today.day + 7),
      );
      expect(generated, isNotEmpty);
    });

    test('generated showups appear on calendar after load', () async {
      // Repo starts empty; pact starts today → load must generate + display
      final showupRepo = InMemoryShowupRepository();
      final pact = _dailyPact(id: 'p1', startDate: today);

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(InMemoryPactRepository([pact])),
          showupRepositoryProvider.overrideWithValue(showupRepo),
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

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(InMemoryPactRepository([pact])),
          showupRepositoryProvider.overrideWithValue(showupRepo),
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

      final container = ProviderContainer(
        overrides: [
          pactRepositoryProvider.overrideWithValue(InMemoryPactRepository([stoppedPact])),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          todayProvider.overrideWithValue(today),
        ],
      );

      await container.read(dashboardViewModelProvider.notifier).load();

      final all = await showupRepo.getShowupsForPact('p1');
      expect(all, isEmpty);
    });
  });
}

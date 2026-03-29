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

    test('empty state — no showups', () async {
      container = createContainer(
        pacts: [
          Pact(
            id: '1',
            habitName: 'Meditate',
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 9, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
          ),
        ],
      );

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

      container = createContainer(showups: [showupToday, showupYesterday]);

      await container.read(dashboardViewModelProvider.notifier).load();
      final state = container.read(dashboardViewModelProvider);

      // Today is index 3
      expect(state.calendarDays[3].showups, [showupToday]);
      // Yesterday is index 2
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

      container = createContainer(showups: [showupMar27]);

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
}

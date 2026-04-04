import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';

void main() {
  group('ShowupGenerator + ShowupRepository integration', () {
    test('generated showup ids are unique within a single pact', () {
      final pact = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2054, 1, 1),
        endDate: DateTime(2054, 6, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

      final showups = ShowupGenerator.generate(pact);
      final ids = showups.map((s) => s.id).toSet();

      expect(ids.length, showups.length,
          reason: 'Every generated showup must have a unique id');
    });

    test('generated showup ids are unique across two pacts with the same schedule', () {
      final pact1 = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2054, 4, 1),
        endDate: DateTime(2054, 4, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      final pact2 = Pact(
        id: 'pact-2',
        habitName: 'Jog',
        startDate: DateTime(2054, 4, 1),
        endDate: DateTime(2054, 4, 30),
        showupDuration: const Duration(minutes: 30),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

      final all = [
        ...ShowupGenerator.generate(pact1),
        ...ShowupGenerator.generate(pact2),
      ];
      final ids = all.map((s) => s.id).toSet();

      expect(ids.length, all.length,
          reason: 'Showup ids must be unique across different pacts');
    });

    test('all generated showups can be saved and retrieved without collision', () async {
      final repo = InMemoryShowupRepository();
      final pact = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2054, 4, 1),
        endDate: DateTime(2054, 4, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

      final showups = ShowupGenerator.generate(pact);
      final result = await repo.saveShowups(showups);

      expect(result.allSaved, isTrue,
          reason: 'No showup ids should collide during save');

      final saved = await repo.getShowupsForPact('pact-1');
      expect(saved.length, showups.length);
    });
  });

  group('Pact creation → Dashboard wiring integration', () {
    test(
        'submitting a pact generates showups visible on the dashboard',
        () async {
      final today = DateTime(2054, 4, 1);
      final pactRepo = InMemoryPactRepository();
      final showupRepo = InMemoryShowupRepository();

      final container = ProviderContainer(
        overrides: [
          // Pact creation providers
          pactCreationTodayProvider.overrideWithValue(today),
          pactCreationRepositoryProvider.overrideWithValue(pactRepo),
          pactCreationShowupRepositoryProvider
              .overrideWithValue(showupRepo),
          // Dashboard providers
          todayProvider.overrideWithValue(today),
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
        ],
      );
      addTearDown(container.dispose);

      // Create a pact via the creation view model
      final creationVM =
          container.read(pactCreationViewModelProvider.notifier);
      creationVM.setHabitName('Meditate');
      creationVM.setShowupDuration(const Duration(minutes: 10));
      creationVM.setScheduleType(ScheduleType.daily);
      creationVM.setSchedule(
          const DailySchedule(timeOfDay: Duration(hours: 7)));
      creationVM.setCommitmentAccepted(true);

      await creationVM.submit();

      // Verify pact was saved
      final creationState = container.read(pactCreationViewModelProvider);
      expect(creationState.submitError, isNull);

      // Load the dashboard
      await container
          .read(dashboardViewModelProvider.notifier)
          .load();

      final dashState = container.read(dashboardViewModelProvider);
      expect(dashState.isLoading, false);

      // Today (index 3) should have a showup
      final todayShowups = dashState.calendarDays[3].showups;
      expect(todayShowups, isNotEmpty);
      expect(todayShowups.first.duration, const Duration(minutes: 10));

      // Pact name should be mapped
      final pactId = todayShowups.first.pactId;
      expect(dashState.habitName(pactId), 'Meditate');
    });
  });
}

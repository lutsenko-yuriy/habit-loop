import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_view_model.dart';

void main() {
  late ProviderContainer container;
  late InMemoryPactRepository pactRepo;
  final today = DateTime(2026, 3, 30);

  setUp(() {
    pactRepo = InMemoryPactRepository();
    container = ProviderContainer(
      overrides: [
        pactCreationTodayProvider.overrideWithValue(today),
        pactCreationRepositoryProvider.overrideWithValue(pactRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  PactCreationState readState() =>
      container.read(pactCreationViewModelProvider);

  PactCreationViewModel readVM() =>
      container.read(pactCreationViewModelProvider.notifier);

  group('PactCreationViewModel', () {
    test('initial state has correct defaults', () {
      final state = readState();
      expect(state.currentStep, PactCreationStep.pactDuration);
      expect(state.habitName, '');
      expect(state.startDate, today);
      expect(state.endDate, DateTime(2026, 9, 30));
      expect(state.commitmentAccepted, false);
    });

    test('setHabitName updates habit name', () {
      readVM().setHabitName('Meditate');
      expect(readState().habitName, 'Meditate');
    });

    test('setStartDate updates start date', () {
      final newDate = DateTime(2026, 4, 1);
      readVM().setStartDate(newDate);
      expect(readState().startDate, newDate);
    });

    test('setEndDate updates end date', () {
      final newDate = DateTime(2026, 12, 1);
      readVM().setEndDate(newDate);
      expect(readState().endDate, newDate);
    });

    test('setShowupDuration updates duration', () {
      readVM().setShowupDuration(const Duration(minutes: 15));
      expect(readState().showupDuration, const Duration(minutes: 15));
    });

    test('setScheduleType sets type and a default schedule', () {
      readVM().setScheduleType(ScheduleType.daily);
      expect(readState().scheduleType, ScheduleType.daily);
      expect(readState().schedule, isA<DailySchedule>());

      readVM().setScheduleType(ScheduleType.weekday);
      expect(readState().scheduleType, ScheduleType.weekday);
      expect(readState().schedule, isA<WeekdaySchedule>());
    });

    test('setSchedule updates schedule', () {
      const schedule = DailySchedule(timeOfDay: Duration(hours: 7));
      readVM().setSchedule(schedule);
      expect(readState().schedule, schedule);
    });

    test('setReminderOffset updates reminder', () {
      readVM().setReminderOffset(const Duration(minutes: 30));
      expect(readState().reminderOffset, const Duration(minutes: 30));
    });

    test('clearReminderOffset sets reminder to null', () {
      readVM().setReminderOffset(const Duration(minutes: 30));
      readVM().clearReminderOffset();
      expect(readState().reminderOffset, isNull);
    });

    test('setCommitmentAccepted updates acceptance', () {
      readVM().setCommitmentAccepted(true);
      expect(readState().commitmentAccepted, true);
    });

    test('nextStep advances when step is valid', () {
      // Step 0 requires valid dates (defaults are valid)
      readVM().nextStep();
      expect(readState().currentStep, PactCreationStep.showupDuration);
    });

    test('nextStep to step 1 defaults showupDuration to 10 min', () {
      readVM().nextStep();
      expect(readState().showupDuration, const Duration(minutes: 10));
    });

    test('nextStep does not advance when step is invalid', () {
      // Step 0 with invalid dates (end before start)
      readVM().setStartDate(DateTime(2026, 10, 1));
      readVM().setEndDate(DateTime(2026, 3, 1));
      readVM().nextStep();
      expect(readState().currentStep, PactCreationStep.pactDuration);
    });

    test('previousStep goes back', () {
      readVM().nextStep();
      expect(readState().currentStep, PactCreationStep.showupDuration);

      readVM().previousStep();
      expect(readState().currentStep, PactCreationStep.pactDuration);
    });

    test('previousStep does not go below 0', () {
      readVM().previousStep();
      expect(readState().currentStep, PactCreationStep.pactDuration);
    });

    test('submit creates pact and saves to repository', () async {
      final vm = readVM();

      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(
          const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final pacts = await pactRepo.getActivePacts();
      expect(pacts, hasLength(1));
      expect(pacts.first.habitName, 'Meditate');
      expect(pacts.first.showupDuration, const Duration(minutes: 10));
      expect(pacts.first.schedule,
          const DailySchedule(timeOfDay: Duration(hours: 7)));
      expect(pacts.first.startDate, today);
      expect(pacts.first.endDate, DateTime(2026, 9, 30));
      expect(pacts.first.reminderOffset, isNull);
    });

    test('submit with reminder saves reminder offset', () async {
      final vm = readVM();

      vm.setHabitName('Jog');
      vm.setShowupDuration(const Duration(minutes: 30));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(
          const DailySchedule(timeOfDay: Duration(hours: 6)));
      vm.setReminderOffset(const Duration(minutes: 15));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final pacts = await pactRepo.getActivePacts();
      expect(pacts.first.reminderOffset, const Duration(minutes: 15));
    });
  });
}

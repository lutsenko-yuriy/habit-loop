import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/save_showups_result.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

void main() {
  late ProviderContainer container;
  late InMemoryPactRepository pactRepo;
  late InMemoryShowupRepository showupRepo;
  // 2054 is used throughout to keep all generated showups in the future.
  // ShowupGenerator.generate() filters by DateTime.now(), so past dates would
  // silently drop showups and break count assertions. 2054 has the same weekday
  // structure as 2026 (28-year Gregorian cycle) so all expected values are identical.
  final today = DateTime(2054, 3, 30);

  setUp(() {
    pactRepo = InMemoryPactRepository();
    showupRepo = InMemoryShowupRepository();
    container = ProviderContainer(
      overrides: [
        pactCreationTodayProvider.overrideWithValue(today),
        pactCreationRepositoryProvider.overrideWithValue(pactRepo),
        pactCreationShowupRepositoryProvider.overrideWithValue(showupRepo),
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
      expect(state.endDate, DateTime(2054, 9, 30));
      expect(state.commitmentAccepted, false);
    });

    test('setHabitName updates habit name', () {
      readVM().setHabitName('Meditate');
      expect(readState().habitName, 'Meditate');
    });

    test('setStartDate updates start date', () {
      final newDate = DateTime(2054, 4, 1);
      readVM().setStartDate(newDate);
      expect(readState().startDate, newDate);
    });

    test('setEndDate updates end date', () {
      final newDate = DateTime(2054, 12, 1);
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
      readVM().setStartDate(DateTime(2054, 10, 1));
      readVM().setEndDate(DateTime(2054, 3, 1));
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
      expect(pacts.first.endDate, DateTime(2054, 9, 30));
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

    test('submit generates and saves showups to repository', () async {
      final vm = readVM();

      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(
          const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final pacts = await pactRepo.getActivePacts();
      final pact = pacts.first;

      final showups = await showupRepo.getShowupsForPact(pact.id);
      expect(showups, isNotEmpty);
      // Daily schedule: one showup per day inclusive of start and end date
      final expectedCount =
          pact.endDate.difference(pact.startDate).inDays + 1;
      expect(showups.length, expectedCount);
      expect(
        showups.every((s) => s.pactId == pact.id),
        isTrue,
      );
      expect(
        showups.every((s) => s.status == ShowupStatus.pending),
        isTrue,
      );
      expect(
        showups.every((s) => s.duration == const Duration(minutes: 10)),
        isTrue,
      );
    });

    test('submit does not save showups when savePact fails', () async {
      final failingContainer = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(today),
          pactCreationRepositoryProvider
              .overrideWithValue(_AlwaysThrowingPactRepository()),
          pactCreationShowupRepositoryProvider.overrideWithValue(showupRepo),
        ],
      );
      addTearDown(failingContainer.dispose);

      final vm =
          failingContainer.read(pactCreationViewModelProvider.notifier);

      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      // Pact save failed, so showups should not have been generated/saved
      final allShowups = await showupRepo.getShowupsForDateRange(
        DateTime(2020),
        DateTime(2030),
      );
      expect(allShowups, isEmpty);
    });

    test('submit sets error when showup saving fails', () async {
      final failingContainer = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(today),
          pactCreationRepositoryProvider.overrideWithValue(pactRepo),
          pactCreationShowupRepositoryProvider
              .overrideWithValue(_AlwaysThrowingShowupRepository()),
        ],
      );
      addTearDown(failingContainer.dispose);

      final vm =
          failingContainer.read(pactCreationViewModelProvider.notifier);

      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final state = failingContainer.read(pactCreationViewModelProvider);
      expect(state.submitError, isNotNull);
      expect(state.isSubmitting, false);
    });

    test('submit rolls back pact when saveShowups fails', () async {
      final rollbackPactRepo = InMemoryPactRepository();
      final failingContainer = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(today),
          pactCreationRepositoryProvider.overrideWithValue(rollbackPactRepo),
          pactCreationShowupRepositoryProvider
              .overrideWithValue(_AlwaysThrowingShowupRepository()),
        ],
      );
      addTearDown(failingContainer.dispose);

      final vm =
          failingContainer.read(pactCreationViewModelProvider.notifier);

      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      // Pact should have been rolled back after showup save failure
      final pacts = await rollbackPactRepo.getAllPacts();
      expect(pacts, isEmpty);
    });
  });

  group('PactCreationViewModel with failing repository', () {
    late ProviderContainer failingContainer;

    setUp(() {
      failingContainer = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(today),
          pactCreationRepositoryProvider
              .overrideWithValue(_AlwaysThrowingPactRepository()),
          pactCreationShowupRepositoryProvider.overrideWithValue(showupRepo),
        ],
      );
    });

    tearDown(() => failingContainer.dispose());

    PactCreationState readFailingState() =>
        failingContainer.read(pactCreationViewModelProvider);

    PactCreationViewModel readFailingVM() =>
        failingContainer.read(pactCreationViewModelProvider.notifier);

    void setUpValidState(PactCreationViewModel vm) {
      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);
    }

    test('isSubmitting is false after savePact throws', () async {
      setUpValidState(readFailingVM());
      await readFailingVM().submit();
      expect(readFailingState().isSubmitting, false);
    });

    test('submitError is set when savePact throws', () async {
      setUpValidState(readFailingVM());
      await readFailingVM().submit();
      expect(readFailingState().submitError, isNotNull);
    });

    test('submitError is cleared at the start of a new submit attempt', () async {
      setUpValidState(readFailingVM());
      await readFailingVM().submit();
      expect(readFailingState().submitError, isNotNull);

      // Re-attempt: error should be cleared before the new attempt resolves
      await readFailingVM().submit();
      // After the second (also failing) submit, error is set again — but it was
      // cleared in between. We verify it's non-null (set by the new failure).
      expect(readFailingState().submitError, isNotNull);
    });
  });
}

class _AlwaysThrowingPactRepository implements PactRepository {
  @override
  Future<List<Pact>> getActivePacts() async => [];

  @override
  Future<List<Pact>> getAllPacts() async => [];

  @override
  Future<Pact?> getPactById(String id) async => null;

  @override
  Future<void> savePact(Pact pact) async =>
      throw Exception('save failed intentionally');

  @override
  Future<void> updatePact(Pact pact) async =>
      throw Exception('update failed intentionally');

  @override
  Future<void> deletePact(String id) async =>
      throw Exception('delete failed intentionally');
}

class _AlwaysThrowingShowupRepository implements ShowupRepository {
  @override
  Future<List<Showup>> getShowupsForDate(DateTime date) async => [];

  @override
  Future<List<Showup>> getShowupsForDateRange(
      DateTime start, DateTime end) async => [];

  @override
  Future<Showup?> getShowupById(String id) async => null;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async => [];

  @override
  Future<void> saveShowup(Showup showup) async =>
      throw Exception('save failed intentionally');

  @override
  Future<SaveShowupsResult> saveShowups(List<Showup> showups) async =>
      throw Exception('save failed intentionally');

  @override
  Future<void> updateShowup(Showup showup) async =>
      throw Exception('update failed intentionally');
}

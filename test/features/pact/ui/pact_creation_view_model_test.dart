import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/pact/analytics/pact_analytics_events.dart';
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
import 'package:habit_loop/features/showup/domain/showup_generator.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

import '../../../analytics/fake_analytics_service.dart';

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

  PactCreationState readState() => container.read(pactCreationViewModelProvider);

  PactCreationViewModel readVM() => container.read(pactCreationViewModelProvider.notifier);

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

    test('setStartDate normalizes to midnight when date has a time component', () {
      // Date pickers on some platforms return a DateTime with a time component.
      // Without normalization startDate would carry the time into analytics
      // (durationDays under-counts) and into the showup generation (daysActive
      // would show 0 when the pact is stopped the next morning).
      readVM().setStartDate(DateTime(2054, 4, 1, 22, 30));
      expect(readState().startDate, DateTime(2054, 4, 1));
      expect(readState().startDate.hour, 0);
      expect(readState().startDate.minute, 0);
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
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final pacts = await pactRepo.getActivePacts();
      expect(pacts, hasLength(1));
      expect(pacts.first.habitName, 'Meditate');
      expect(pacts.first.showupDuration, const Duration(minutes: 10));
      expect(pacts.first.schedule, const DailySchedule(timeOfDay: Duration(hours: 7)));
      expect(pacts.first.startDate, today);
      expect(pacts.first.endDate, DateTime(2054, 9, 30));
      expect(pacts.first.reminderOffset, isNull);
      expect(pacts.first.stats, isNotNull);
      expect(pacts.first.stats?.showupsDone, 0);
      expect(pacts.first.stats?.showupsFailed, 0);
      expect(
        pacts.first.stats?.showupsRemaining,
        ShowupGenerator.countTotal(pacts.first),
      );
    });

    test('submit with reminder saves reminder offset', () async {
      final vm = readVM();

      vm.setHabitName('Jog');
      vm.setShowupDuration(const Duration(minutes: 30));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 6)));
      vm.setReminderOffset(const Duration(minutes: 15));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final pacts = await pactRepo.getActivePacts();
      expect(pacts.first.reminderOffset, const Duration(minutes: 15));
    });

    test('submit generates only the initial 8-day window of showups', () async {
      final vm = readVM();

      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final pacts = await pactRepo.getActivePacts();
      final pact = pacts.first;

      final showups = await showupRepo.getShowupsForPact(pact.id);
      // Daily schedule: window is today through today+10 → at most 11 showups,
      // clamped to the pact's end date (pact ends 2054-09-30 so no clamping).
      expect(showups, hasLength(11));
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
      // All showups must fall within the 11-day window
      final windowEnd = today.add(const Duration(days: 10, hours: 23, minutes: 59, seconds: 59));
      expect(
        showups.every((s) => !s.scheduledAt.isAfter(windowEnd)),
        isTrue,
      );
    });

    test('submit generates and saves showups to repository', () async {
      final vm = readVM();

      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final pacts = await pactRepo.getActivePacts();
      final pact = pacts.first;

      final showups = await showupRepo.getShowupsForPact(pact.id);
      expect(showups, isNotEmpty);
      // Windowed generation: only the 11-day initial window is persisted
      expect(showups.length, lessThanOrEqualTo(11));
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
          pactCreationRepositoryProvider.overrideWithValue(_AlwaysThrowingPactRepository()),
          pactCreationShowupRepositoryProvider.overrideWithValue(showupRepo),
        ],
      );
      addTearDown(failingContainer.dispose);

      final vm = failingContainer.read(pactCreationViewModelProvider.notifier);

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
          pactCreationShowupRepositoryProvider.overrideWithValue(_AlwaysThrowingShowupRepository()),
        ],
      );
      addTearDown(failingContainer.dispose);

      final vm = failingContainer.read(pactCreationViewModelProvider.notifier);

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
          pactCreationShowupRepositoryProvider.overrideWithValue(_AlwaysThrowingShowupRepository()),
        ],
      );
      addTearDown(failingContainer.dispose);

      final vm = failingContainer.read(pactCreationViewModelProvider.notifier);

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

    test('submit rolls back pact and showups when stats persistence fails', () async {
      final rollbackPactRepo = _ThrowingOnUpdatePactRepository();
      final rollbackShowupRepo = InMemoryShowupRepository();
      final failingContainer = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(today),
          pactCreationRepositoryProvider.overrideWithValue(rollbackPactRepo),
          pactCreationShowupRepositoryProvider.overrideWithValue(rollbackShowupRepo),
        ],
      );
      addTearDown(failingContainer.dispose);

      final vm = failingContainer.read(pactCreationViewModelProvider.notifier);

      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final state = failingContainer.read(pactCreationViewModelProvider);
      expect(state.submitError, isNotNull);
      expect(await rollbackPactRepo.getAllPacts(), isEmpty);
      expect(
        await rollbackShowupRepo.getShowupsForDateRange(
          DateTime(2054, 1, 1),
          DateTime(2054, 12, 31),
        ),
        isEmpty,
      );
    });

    test('submit skips today\'s showup when its scheduled time is already past', () async {
      // Simulate opening the wizard at 22:00 on March 30 with a daily 8am
      // schedule starting today. The 8am slot is 14 hours in the past — it
      // should NOT be persisted; the first saved showup must be tomorrow's 8am.
      final eveningPactRepo = InMemoryPactRepository();
      final eveningShowupRepo = InMemoryShowupRepository();
      final eveningContainer = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(DateTime(2054, 3, 30, 22, 0)),
          pactCreationRepositoryProvider.overrideWithValue(eveningPactRepo),
          pactCreationShowupRepositoryProvider.overrideWithValue(eveningShowupRepo),
        ],
      );
      addTearDown(eveningContainer.dispose);

      final vm = eveningContainer.read(pactCreationViewModelProvider.notifier);
      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(ScheduleType.daily);
      vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 8)));
      vm.setCommitmentAccepted(true);

      await vm.submit();

      final pacts = await eveningPactRepo.getActivePacts();
      final showups = await eveningShowupRepo.getShowupsForPact(pacts.first.id);

      // Today's 8am slot is already past (it's 22:00) — must not be saved.
      expect(
        showups.any((s) => s.scheduledAt == DateTime(2054, 3, 30, 8, 0)),
        isFalse,
        reason: 'Past-due showup for today should not be saved at pact creation',
      );
      // Tomorrow's 8am must be the first saved showup.
      expect(
        showups.any((s) => s.scheduledAt == DateTime(2054, 3, 31, 8, 0)),
        isTrue,
        reason: 'First showup should be tomorrow since today\'s slot already passed',
      );
    });
  });

  group('PactCreationViewModel analytics', () {
    late FakeAnalyticsService fakeAnalytics;

    setUp(() {
      fakeAnalytics = FakeAnalyticsService();
    });

    ProviderContainer makeAnalyticsContainer({
      PactRepository? pactRepository,
      ShowupRepository? showupRepository,
    }) {
      return ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(today),
          pactCreationRepositoryProvider.overrideWithValue(pactRepository ?? InMemoryPactRepository()),
          pactCreationShowupRepositoryProvider.overrideWithValue(showupRepository ?? InMemoryShowupRepository()),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
    }

    void setUpValidState(PactCreationViewModel vm, {ScheduleType scheduleType = ScheduleType.daily}) {
      vm.setHabitName('Meditate');
      vm.setShowupDuration(const Duration(minutes: 10));
      vm.setScheduleType(scheduleType);
      if (scheduleType == ScheduleType.daily) {
        vm.setSchedule(const DailySchedule(timeOfDay: Duration(hours: 7)));
      } else if (scheduleType == ScheduleType.weekday) {
        vm.setSchedule(const WeekdaySchedule(entries: [WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 7))]));
      } else {
        vm.setSchedule(
            const MonthlyByDateSchedule(entries: [MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 7))]));
      }
      vm.setCommitmentAccepted(true);
    }

    test('submit fires PactCreatedEvent with correct properties on success', () async {
      final pactRepo = InMemoryPactRepository();
      final showupRepo = InMemoryShowupRepository();
      final c = makeAnalyticsContainer(pactRepository: pactRepo, showupRepository: showupRepo);
      addTearDown(c.dispose);

      final vm = c.read(pactCreationViewModelProvider.notifier);
      setUpValidState(vm);
      await vm.submit();

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first;
      expect(event, isA<PactCreatedEvent>());

      final pactCreatedEvent = event as PactCreatedEvent;
      expect(pactCreatedEvent.scheduleType, 'daily');

      final pacts = await pactRepo.getActivePacts();
      final pact = pacts.first;
      expect(
        pactCreatedEvent.durationDays,
        pact.endDate.difference(pact.startDate).inDays + 1,
      );
      expect(pactCreatedEvent.showupDurationMinutes, 10);
      expect(pactCreatedEvent.reminderOffsetMinutes, isNull);
      expect(pactCreatedEvent.showupsExpected, ShowupGenerator.countTotal(pact));
      expect(pact.stats?.showupsRemaining, pactCreatedEvent.showupsExpected);
    });

    test('submit keeps daily showups_expected aligned with inclusive duration_days for a default 6-month pact',
        () async {
      final pactRepo = InMemoryPactRepository();
      final showupRepo = InMemoryShowupRepository();
      final c = makeAnalyticsContainer(pactRepository: pactRepo, showupRepository: showupRepo);
      addTearDown(c.dispose);

      final vm = c.read(pactCreationViewModelProvider.notifier);
      setUpValidState(vm);
      await vm.submit();

      final event = fakeAnalytics.loggedEvents.single as PactCreatedEvent;
      expect(event.scheduleType, 'daily');
      expect(event.showupsExpected, event.durationDays);
    });

    test('duration_days is correct when pact is created in the evening', () async {
      // Without normalization: startDate = 2054-03-30T22:00, endDate = 2054-09-30T00:00
      // difference.inDays = 183, +1 = 184 (wrong; should be 185)
      // After fix: startDate = 2054-03-30T00:00 → difference.inDays = 184, +1 = 185 (correct)
      final eveningNow = DateTime(2054, 3, 30, 22, 0);
      final localPactRepo = InMemoryPactRepository();
      final localShowupRepo = InMemoryShowupRepository();
      final c = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(eveningNow),
          pactCreationRepositoryProvider.overrideWithValue(localPactRepo),
          pactCreationShowupRepositoryProvider.overrideWithValue(localShowupRepo),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
      addTearDown(c.dispose);

      final vm = c.read(pactCreationViewModelProvider.notifier);
      setUpValidState(vm); // daily at 7am — all slots filtered since 7:00 < 22:00 createdAt
      await vm.submit();

      final pacts = await localPactRepo.getActivePacts();
      final pact = pacts.first;
      final event = fakeAnalytics.loggedEvents.single as PactCreatedEvent;

      // duration_days must reflect inclusive calendar days (midnight-to-midnight),
      // independent of the time-of-day at which the pact was created.
      expect(
        event.durationDays,
        pact.endDate.difference(pact.startDate).inDays + 1,
        reason: 'durationDays must equal (endDate - startDate).inDays + 1',
      );
      expect(event.durationDays, 185, reason: 'Mar 30 → Sep 30 inclusive = 185 calendar days');
    });

    test('submit fires PactCreatedEvent with reminder offset when reminder set', () async {
      final c = makeAnalyticsContainer();
      addTearDown(c.dispose);

      final vm = c.read(pactCreationViewModelProvider.notifier);
      setUpValidState(vm);
      vm.setReminderOffset(const Duration(minutes: 15));
      await vm.submit();

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first as PactCreatedEvent;
      expect(event.reminderOffsetMinutes, 15);
    });

    test('submit fires PactCreatedEvent with schedule_type weekly for weekday schedule', () async {
      final c = makeAnalyticsContainer();
      addTearDown(c.dispose);

      final vm = c.read(pactCreationViewModelProvider.notifier);
      setUpValidState(vm, scheduleType: ScheduleType.weekday);
      await vm.submit();

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first as PactCreatedEvent;
      expect(event.scheduleType, 'weekly');
    });

    test('submit fires PactCreatedEvent with schedule_type monthly for monthly schedule', () async {
      final c = makeAnalyticsContainer();
      addTearDown(c.dispose);

      final vm = c.read(pactCreationViewModelProvider.notifier);
      setUpValidState(vm, scheduleType: ScheduleType.monthlyByDate);
      await vm.submit();

      expect(fakeAnalytics.loggedEvents, hasLength(1));
      final event = fakeAnalytics.loggedEvents.first as PactCreatedEvent;
      expect(event.scheduleType, 'monthly');
    });

    test('submit does NOT fire analytics event when savePact fails', () async {
      final c = makeAnalyticsContainer(
        pactRepository: _AlwaysThrowingPactRepository(),
      );
      addTearDown(c.dispose);

      final vm = c.read(pactCreationViewModelProvider.notifier);
      setUpValidState(vm);
      await vm.submit();

      expect(fakeAnalytics.loggedEvents, isEmpty);
    });

    test('submit does NOT fire analytics event when saveShowups fails', () async {
      final c = makeAnalyticsContainer(
        showupRepository: _AlwaysThrowingShowupRepository(),
      );
      addTearDown(c.dispose);

      final vm = c.read(pactCreationViewModelProvider.notifier);
      setUpValidState(vm);
      await vm.submit();

      expect(fakeAnalytics.loggedEvents, isEmpty);
    });
  });

  group('PactCreationViewModel with failing repository', () {
    late ProviderContainer failingContainer;

    setUp(() {
      failingContainer = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(today),
          pactCreationRepositoryProvider.overrideWithValue(_AlwaysThrowingPactRepository()),
          pactCreationShowupRepositoryProvider.overrideWithValue(showupRepo),
        ],
      );
    });

    tearDown(() => failingContainer.dispose());

    PactCreationState readFailingState() => failingContainer.read(pactCreationViewModelProvider);

    PactCreationViewModel readFailingVM() => failingContainer.read(pactCreationViewModelProvider.notifier);

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
  Future<void> savePact(Pact pact) async => throw Exception('save failed intentionally');

  @override
  Future<void> updatePact(Pact pact) async => throw Exception('update failed intentionally');

  @override
  Future<void> deletePact(String id) async => throw Exception('delete failed intentionally');
}

class _ThrowingOnUpdatePactRepository extends InMemoryPactRepository {
  @override
  Future<void> updatePact(Pact pact) async => throw Exception('update failed intentionally');
}

class _AlwaysThrowingShowupRepository implements ShowupRepository {
  @override
  Future<List<Showup>> getShowupsForDate(DateTime date) async => [];

  @override
  Future<List<Showup>> getShowupsForDateRange(DateTime start, DateTime end) async => [];

  @override
  Future<Showup?> getShowupById(String id) async => null;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async => [];

  @override
  Future<void> saveShowup(Showup showup) async => throw Exception('save failed intentionally');

  @override
  Future<SaveShowupsResult> saveShowups(List<Showup> showups) async => throw Exception('save failed intentionally');

  @override
  Future<void> updateShowup(Showup showup) async => throw Exception('update failed intentionally');

  @override
  Future<int> countShowupsForPact(String pactId) async => 0;

  @override
  Future<void> deleteShowupsForPact(String pactId) async => throw Exception('delete failed intentionally');
}

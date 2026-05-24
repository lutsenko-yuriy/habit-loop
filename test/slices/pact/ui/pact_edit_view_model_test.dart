import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_view_model.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({
  required InMemoryPactRepository pactRepo,
  required InMemoryShowupRepository showupRepo,
  required DateTime today,
  List<Override> extras = const [],
}) {
  final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
  final statsService = PactStatsService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: txService,
    syncService: const NoopSyncService(),
  );
  final service = PactService(
    pactRepository: pactRepo,
    showupRepository: showupRepo,
    transactionService: txService,
    syncService: const NoopSyncService(),
    pactStatsService: statsService,
  );
  return ProviderContainer(
    overrides: [
      pactEditTodayProvider.overrideWithValue(today),
      pactServiceProvider.overrideWithValue(service),
      pactStatsServiceProvider.overrideWithValue(statsService),
      ...extras,
    ],
  );
}

/// Creates a simple active pact for testing.
///
/// Uses year 2054 so all generated showups are in the future and never
/// accidentally pass the "now > scheduledAt + duration" auto-fail check.
Pact _makePact({
  String id = 'pact-1',
  String habitName = 'Meditate',
  Duration? reminderOffset,
}) {
  final today = DateTime(2054, 3, 30);
  return Pact(
    id: id,
    habitName: habitName,
    startDate: today,
    endDate: DateTime(2054, 9, 30),
    showupDuration: const Duration(minutes: 15),
    schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
    status: PactStatus.active,
    reminderOffset: reminderOffset,
    createdAt: today,
  );
}

/// Creates a pending showup scheduled in the far future (qualifying for
/// reminder scheduling).
Showup _makeFutureShowup({String pactId = 'pact-1', String id = 'su-1'}) {
  return Showup(
    id: id,
    pactId: pactId,
    scheduledAt: DateTime(2054, 4, 1, 8, 0),
    duration: const Duration(minutes: 15),
    status: ShowupStatus.pending,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late ProviderContainer container;
  late InMemoryPactRepository pactRepo;
  late InMemoryShowupRepository showupRepo;
  late FakeAnalyticsService analytics;
  late FakeNotificationService notifications;
  final today = DateTime(2054, 3, 30);

  setUp(() {
    pactRepo = InMemoryPactRepository();
    showupRepo = InMemoryShowupRepository();
    analytics = FakeAnalyticsService();
    notifications = FakeNotificationService();
    container = _makeContainer(
      pactRepo: pactRepo,
      showupRepo: showupRepo,
      today: today,
      extras: [
        analyticsServiceProvider.overrideWithValue(analytics),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() => container.dispose());

  PactEditWizardState readState(String pactId) => container.read(pactEditViewModelProvider(pactId));

  PactEditViewModel readVM(String pactId) => container.read(pactEditViewModelProvider(pactId).notifier);

  group('PactEditViewModel', () {
    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('initial state has isLoading false, no wizardState, no originalPact', () {
      final state = readState('pact-1');
      expect(state.isLoading, false);
      expect(state.wizardState, isNull);
      expect(state.originalPact, isNull);
      expect(state.isSaving, false);
      expect(state.saveError, isNull);
    });

    // -------------------------------------------------------------------------
    // load()
    // -------------------------------------------------------------------------

    group('load()', () {
      test('populates wizardState and originalPact from the persisted pact', () async {
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        await pactRepo.savePact(pact);

        await readVM('pact-1').load();
        final state = readState('pact-1');

        expect(state.isLoading, false);
        expect(state.loadError, isNull);
        expect(state.wizardState, isNotNull);
        expect(state.originalPact, isNotNull);
        expect(state.wizardState!.habitName, 'Meditate');
        expect(state.wizardState!.reminderOffset, const Duration(minutes: 10));
        expect(state.originalPact!.id, 'pact-1');
      });

      test('initialises wizardState with currentStep = habitName', () async {
        await pactRepo.savePact(_makePact());
        await readVM('pact-1').load();
        expect(readState('pact-1').wizardState!.currentStep, PactWizardStep.habitName);
      });

      test('preserves schedule and showupDuration from the original pact', () async {
        await pactRepo.savePact(_makePact());
        await readVM('pact-1').load();

        final ws = readState('pact-1').wizardState!;
        // fromPact() migrates legacy schedule types to SlotSchedule; a
        // DailySchedule (every day at 08:00) becomes a WeeklySlot covering
        // all 7 weekdays at the same time.
        expect(ws.schedule, isA<SlotSchedule>());
        final slot = ws.schedule as SlotSchedule;
        expect(slot.slots.length, 1);
        expect(slot.slots.first, isA<WeeklySlot>());
        expect((slot.slots.first as WeeklySlot).weekdays, {1, 2, 3, 4, 5, 6, 7});
        expect((slot.slots.first as WeeklySlot).timeOfDay, const Duration(hours: 8));
        expect(ws.showupDuration, const Duration(minutes: 15));
      });

      test('sets loadError when pact is not found', () async {
        await readVM('nonexistent').load();
        final state = readState('nonexistent');
        expect(state.isLoading, false);
        expect(state.loadError, isNotNull);
        expect(state.wizardState, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Field setters — require prior load()
    // -------------------------------------------------------------------------

    group('setHabitName()', () {
      setUp(() async {
        await pactRepo.savePact(_makePact());
        await readVM('pact-1').load();
      });

      test('updates wizardState.habitName', () {
        readVM('pact-1').setHabitName('Jogging');
        expect(readState('pact-1').wizardState!.habitName, 'Jogging');
      });

      test('is a no-op when wizardState is null', () {
        // Container that was never loaded
        final fresh = _makeContainer(pactRepo: InMemoryPactRepository(), showupRepo: showupRepo, today: today);
        addTearDown(fresh.dispose);
        fresh.read(pactEditViewModelProvider('pact-1').notifier).setHabitName('Jogging');
        expect(fresh.read(pactEditViewModelProvider('pact-1')).wizardState, isNull);
      });
    });

    group('setReminderOffset()', () {
      setUp(() async {
        await pactRepo.savePact(_makePact());
        await readVM('pact-1').load();
      });

      test('updates wizardState.reminderOffset', () {
        readVM('pact-1').setReminderOffset(const Duration(minutes: 15));
        expect(readState('pact-1').wizardState!.reminderOffset, const Duration(minutes: 15));
      });
    });

    group('clearReminderOffset()', () {
      setUp(() async {
        await pactRepo.savePact(_makePact(reminderOffset: const Duration(minutes: 10)));
        await readVM('pact-1').load();
      });

      test('clears wizardState.reminderOffset to null', () {
        readVM('pact-1').clearReminderOffset();
        expect(readState('pact-1').wizardState!.reminderOffset, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // goToPage() — 3-step mapping
    // -------------------------------------------------------------------------

    group('goToPage()', () {
      setUp(() async {
        await pactRepo.savePact(_makePact());
        await readVM('pact-1').load();
      });

      test('page 0 maps to PactWizardStep.habitName', () {
        readVM('pact-1').goToPage(0);
        expect(readState('pact-1').wizardState!.currentStep, PactWizardStep.habitName);
      });

      test('page 1 maps to PactWizardStep.reminder', () {
        readVM('pact-1').goToPage(1);
        expect(readState('pact-1').wizardState!.currentStep, PactWizardStep.reminder);
      });

      test('page 2 maps to PactWizardStep.summary', () {
        readVM('pact-1').goToPage(2);
        expect(readState('pact-1').wizardState!.currentStep, PactWizardStep.summary);
      });

      test('out-of-range page is clamped', () {
        readVM('pact-1').goToPage(10);
        expect(readState('pact-1').wizardState!.currentStep, PactWizardStep.summary);

        readVM('pact-1').goToPage(-1);
        expect(readState('pact-1').wizardState!.currentStep, PactWizardStep.habitName);
      });
    });

    // -------------------------------------------------------------------------
    // markSummaryJumped()
    // -------------------------------------------------------------------------

    group('markSummaryJumped()', () {
      setUp(() async {
        await pactRepo.savePact(_makePact());
        await readVM('pact-1').load();
      });

      test('sets usedSummaryJump to true', () {
        expect(readState('pact-1').wizardState!.usedSummaryJump, false);
        readVM('pact-1').markSummaryJumped();
        expect(readState('pact-1').wizardState!.usedSummaryJump, true);
      });

      test('is idempotent — calling twice does not flip back', () {
        readVM('pact-1').markSummaryJumped();
        readVM('pact-1').markSummaryJumped();
        expect(readState('pact-1').wizardState!.usedSummaryJump, true);
      });
    });

    // -------------------------------------------------------------------------
    // save()
    // -------------------------------------------------------------------------

    group('save()', () {
      test('is a no-op when not yet loaded (wizardState is null)', () async {
        await readVM('pact-1').save();
        expect(readState('pact-1').isSaving, false);
        expect(readState('pact-1').saveError, isNull);
      });

      test('persists habitName change to the repository', () async {
        await pactRepo.savePact(_makePact(habitName: 'Meditate'));
        await readVM('pact-1').load();

        readVM('pact-1').setHabitName('Jogging');
        await readVM('pact-1').save();

        final updated = await pactRepo.getPactById('pact-1');
        expect(updated!.habitName, 'Jogging');
        expect(readState('pact-1').isSaving, false);
        expect(readState('pact-1').saveError, isNull);
      });

      test('trims leading/trailing whitespace from habitName before saving', () async {
        await pactRepo.savePact(_makePact(habitName: 'Meditate'));
        await readVM('pact-1').load();

        readVM('pact-1').setHabitName('  Jogging  ');
        await readVM('pact-1').save();

        final updated = await pactRepo.getPactById('pact-1');
        expect(updated!.habitName, 'Jogging');
      });

      test('persists reminderOffset change to the repository', () async {
        await pactRepo.savePact(_makePact(reminderOffset: null));
        await readVM('pact-1').load();

        readVM('pact-1').setReminderOffset(const Duration(minutes: 10));
        await readVM('pact-1').save();

        final updated = await pactRepo.getPactById('pact-1');
        expect(updated!.reminderOffset, const Duration(minutes: 10));
      });

      test('persists reminder clearance to the repository', () async {
        await pactRepo.savePact(_makePact(reminderOffset: const Duration(minutes: 10)));
        await readVM('pact-1').load();

        readVM('pact-1').clearReminderOffset();
        await readVM('pact-1').save();

        final updated = await pactRepo.getPactById('pact-1');
        expect(updated!.reminderOffset, isNull);
      });

      // -----------------------------------------------------------------------
      // Analytics
      // -----------------------------------------------------------------------

      group('PactEditSavedEvent', () {
        test('fires with habitNameChanged=true when name was changed', () async {
          await pactRepo.savePact(_makePact(habitName: 'Meditate'));
          await readVM('pact-1').load();

          readVM('pact-1').setHabitName('Jogging');
          await readVM('pact-1').save();
          await Future<void>.delayed(Duration.zero); // pump fire-and-forget

          expect(analytics.loggedEvents, hasLength(1));
          final event = analytics.loggedEvents.first as PactEditSavedEvent;
          expect(event.pactId, 'pact-1');
          expect(event.habitNameChanged, true);
          expect(event.reminderChanged, false);
          expect(event.newReminderOffsetMinutes, isNull);
          expect(event.usedSummaryJump, false);
        });

        test('fires with habitNameChanged=false when name was not changed', () async {
          await pactRepo.savePact(_makePact(habitName: 'Meditate'));
          await readVM('pact-1').load();

          await readVM('pact-1').save();
          await Future<void>.delayed(Duration.zero);

          final event = analytics.loggedEvents.first as PactEditSavedEvent;
          expect(event.habitNameChanged, false);
          expect(event.reminderChanged, false);
        });

        test('fires with reminderChanged=true and offset when reminder was added', () async {
          await pactRepo.savePact(_makePact(reminderOffset: null));
          await readVM('pact-1').load();

          readVM('pact-1').setReminderOffset(const Duration(minutes: 10));
          await readVM('pact-1').save();
          await Future<void>.delayed(Duration.zero);

          final event = analytics.loggedEvents.first as PactEditSavedEvent;
          expect(event.reminderChanged, true);
          expect(event.newReminderOffsetMinutes, 10);
        });

        test('fires with reminderChanged=true and null offset when reminder was cleared', () async {
          await pactRepo.savePact(_makePact(reminderOffset: const Duration(minutes: 10)));
          await readVM('pact-1').load();

          readVM('pact-1').clearReminderOffset();
          await readVM('pact-1').save();
          await Future<void>.delayed(Duration.zero);

          final event = analytics.loggedEvents.first as PactEditSavedEvent;
          expect(event.reminderChanged, true);
          expect(event.newReminderOffsetMinutes, isNull);
        });

        test('fires with usedSummaryJump=true when user jumped from summary', () async {
          await pactRepo.savePact(_makePact());
          await readVM('pact-1').load();

          readVM('pact-1').markSummaryJumped();
          await readVM('pact-1').save();
          await Future<void>.delayed(Duration.zero);

          final event = analytics.loggedEvents.first as PactEditSavedEvent;
          expect(event.usedSummaryJump, true);
        });
      });

      // -----------------------------------------------------------------------
      // Reminder notifications
      // -----------------------------------------------------------------------

      group('reminder notifications', () {
        test('always cancels reminders for the pact on save', () async {
          await pactRepo.savePact(_makePact());
          await readVM('pact-1').load();

          await readVM('pact-1').save();

          expect(notifications.cancelledPactIds, contains('pact-1'));
        });

        test('cancels reminders even when reminder offset is null', () async {
          await pactRepo.savePact(_makePact(reminderOffset: null));
          await readVM('pact-1').load();

          await readVM('pact-1').save();

          expect(notifications.cancelledPactIds, contains('pact-1'));
        });

        test('schedules reminders when new reminder offset is set', () async {
          await pactRepo.savePact(_makePact(reminderOffset: null));
          await showupRepo.saveShowups([_makeFutureShowup()]);
          await readVM('pact-1').load();

          readVM('pact-1').setReminderOffset(const Duration(minutes: 10));
          await readVM('pact-1').save();
          await Future<void>.delayed(Duration.zero); // pump unawaited scheduleReminders

          expect(notifications.scheduledReminders, isNotEmpty);
        });

        test('does not schedule reminders when reminder offset is null', () async {
          await pactRepo.savePact(_makePact(reminderOffset: const Duration(minutes: 10)));
          await showupRepo.saveShowups([_makeFutureShowup()]);
          await readVM('pact-1').load();

          readVM('pact-1').clearReminderOffset();
          await readVM('pact-1').save();
          await Future<void>.delayed(Duration.zero);

          expect(notifications.scheduledReminders, isEmpty);
        });
      });

      // -----------------------------------------------------------------------
      // Error handling
      // -----------------------------------------------------------------------

      test('sets saveError and clears isSaving on failure', () async {
        final failingRepo = _AlwaysThrowingPactRepository();
        final txService = InMemoryPactTransactionService(failingRepo, showupRepo);
        final statsService = PactStatsService(
          pactRepository: failingRepo,
          showupRepository: showupRepo,
          transactionService: txService,
          syncService: const NoopSyncService(),
        );
        final failingService = PactService(
          pactRepository: failingRepo,
          showupRepository: showupRepo,
          transactionService: txService,
          syncService: const NoopSyncService(),
          pactStatsService: statsService,
        );

        final failContainer = ProviderContainer(
          overrides: [
            pactEditTodayProvider.overrideWithValue(today),
            pactServiceProvider.overrideWithValue(failingService),
            pactStatsServiceProvider.overrideWithValue(statsService),
            analyticsServiceProvider.overrideWithValue(analytics),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(failContainer.dispose);

        // Pre-load pact via the original (non-failing) repo to get wizardState
        final pact = _makePact();
        await pactRepo.savePact(pact);
        final goodContainer = _makeContainer(
          pactRepo: pactRepo,
          showupRepo: showupRepo,
          today: today,
          extras: [
            analyticsServiceProvider.overrideWithValue(analytics),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(goodContainer.dispose);
        await goodContainer.read(pactEditViewModelProvider('pact-1').notifier).load();

        // Manually inject the loaded state into the failing container's VM
        // by loading a pact that the failing repo doesn't know about –
        // this triggers the StateError load path. Instead, simulate by seeding
        // the failing repo with the pact, letting load() succeed, then triggering
        // a save error via a fresh container with a save-failing repo.
        final saveFail = _SaveThrowingPactRepository(pact);
        final saveTxService = InMemoryPactTransactionService(saveFail, showupRepo);
        final saveStatsService = PactStatsService(
          pactRepository: saveFail,
          showupRepository: showupRepo,
          transactionService: saveTxService,
          syncService: const NoopSyncService(),
        );
        final saveFailService = PactService(
          pactRepository: saveFail,
          showupRepository: showupRepo,
          transactionService: saveTxService,
          syncService: const NoopSyncService(),
          pactStatsService: saveStatsService,
        );
        final saveFailContainer = ProviderContainer(
          overrides: [
            pactEditTodayProvider.overrideWithValue(today),
            pactServiceProvider.overrideWithValue(saveFailService),
            pactStatsServiceProvider.overrideWithValue(saveStatsService),
            analyticsServiceProvider.overrideWithValue(analytics),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(saveFailContainer.dispose);

        await saveFailContainer.read(pactEditViewModelProvider('pact-1').notifier).load();
        await saveFailContainer.read(pactEditViewModelProvider('pact-1').notifier).save();

        final state = saveFailContainer.read(pactEditViewModelProvider('pact-1'));
        expect(state.saveError, isNotNull);
        expect(state.isSaving, false);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _AlwaysThrowingPactRepository extends InMemoryPactRepository {
  @override
  Future<Pact?> getPactById(String id) async => null;
}

class _SaveThrowingPactRepository extends InMemoryPactRepository {
  _SaveThrowingPactRepository(Pact pact) : super([pact]);

  @override
  Future<void> updatePact(Pact pact) async {
    throw Exception('Simulated DB error on updatePact');
  }
}

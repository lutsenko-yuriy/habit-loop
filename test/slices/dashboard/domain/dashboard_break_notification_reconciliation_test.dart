// Reproduces the HAB-226 bug report: after a fixed-end-date break elapses
// naturally (nobody taps "Resume pact"), do showups scheduled after the
// break's plannedEndDate ever get reminders scheduled by the normal
// day-by-day dashboard load cycle?
//
// Mirrors the real app flow: DashboardViewModel.load() is called once per
// simulated day (advancing todayProvider), exactly like a user opening the
// app once daily, with no explicit break-stop action taken.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/application/pact_break_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/notifications/fake_notification_service.dart';

void main() {
  test(
    'showups scheduled after a fixed-end break elapses naturally get reminders scheduled '
    'within the normal daily dashboard load cycle',
    () async {
      final showupRepo = InMemoryShowupRepository();
      final breakRepo = InMemoryPactBreakRepository();
      final notificationService = FakeNotificationService();

      final pact = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2054, 1, 1),
        endDate: DateTime(2054, 6, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
        reminderOffset: const Duration(minutes: 15),
        createdAt: DateTime(2054, 1, 1),
      );
      final pactRepo = InMemoryPactRepository([pact]);

      DateTime today = DateTime(2054, 1, 1);
      final transactionService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final container = ProviderContainer(
        overrides: [
          todayProvider.overrideWithValue(today),
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactBreakRepositoryProvider.overrideWithValue(breakRepo),
          notificationServiceProvider.overrideWithValue(notificationService),
          pactTransactionServiceProvider.overrideWithValue(transactionService),
        ],
      );
      addTearDown(container.dispose);

      // Day 1: first dashboard load — generates the initial showup window.
      await container.read(dashboardViewModelProvider.notifier).load();

      // Start a 3-day break (day 2 through day 4 inclusive), fixed end date.
      final breakService = PactBreakService(
        pactBreakRepository: breakRepo,
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        reminderSchedulingService: container.read(reminderSchedulingServiceProvider),
        syncService: container.read(syncServiceProvider),
        cache: container.read(pactDetailCacheProvider),
      );
      await breakService.startBreak(
        id: 'b1',
        pactId: 'pact-1',
        startDate: DateTime(2054, 1, 2),
        rationale: 'Travel',
        plannedEndDate: DateTime(2054, 1, 4),
        now: DateTime(2054, 1, 1, 12),
      );

      // Simulate one dashboard load per day for the next 14 days — nobody
      // ever taps "Resume pact"; the break simply elapses on its own.
      for (var i = 1; i <= 14; i++) {
        today = DateTime(2054, 1, 1).add(Duration(days: i));
        container.updateOverrides([
          todayProvider.overrideWithValue(today),
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactBreakRepositoryProvider.overrideWithValue(breakRepo),
          notificationServiceProvider.overrideWithValue(notificationService),
          pactTransactionServiceProvider.overrideWithValue(transactionService),
        ]);
        await container.read(dashboardViewModelProvider.notifier).load();
      }

      // Showups scheduled well after the break ended (day 4) — e.g. day 10 —
      // are not on break by any definition and should have had a reminder
      // scheduled by now, exactly like any other pending future showup.
      final scheduledIds = notificationService.scheduledReminders.map((r) => r.showup.id).toSet();
      final postBreakShowups = (await showupRepo.getShowupsForPact('pact-1'))
          .where((s) => s.scheduledAt.isAfter(DateTime(2054, 1, 5)))
          .toList();

      expect(postBreakShowups, isNotEmpty, reason: 'test setup: expected showups generated past the break window');
      expect(
        postBreakShowups.map((s) => s.id).toSet().difference(scheduledIds),
        isEmpty,
        reason: 'every post-break showup should have a reminder scheduled once the break has naturally elapsed',
      );
    },
  );

  test(
    'single dashboard load, long after a fixed-end break has already elapsed with no loads in between',
    () async {
      final showupRepo = InMemoryShowupRepository();
      final breakRepo = InMemoryPactBreakRepository();
      final notificationService = FakeNotificationService();

      final pact = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2054, 1, 1),
        endDate: DateTime(2054, 6, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
        reminderOffset: const Duration(minutes: 15),
        createdAt: DateTime(2054, 1, 1),
      );
      final pactRepo = InMemoryPactRepository([pact]);
      final transactionService = InMemoryPactTransactionService(pactRepo, showupRepo);

      final container = ProviderContainer(
        overrides: [
          todayProvider.overrideWithValue(DateTime(2054, 1, 1)),
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactBreakRepositoryProvider.overrideWithValue(breakRepo),
          notificationServiceProvider.overrideWithValue(notificationService),
          pactTransactionServiceProvider.overrideWithValue(transactionService),
        ],
      );
      addTearDown(container.dispose);

      // Day 1: first dashboard load — generates the initial showup window
      // (covers day 1 through day 11, well past the break's planned end).
      await container.read(dashboardViewModelProvider.notifier).load();

      final breakService = PactBreakService(
        pactBreakRepository: breakRepo,
        pactRepository: pactRepo,
        showupRepository: showupRepo,
        reminderSchedulingService: container.read(reminderSchedulingServiceProvider),
        syncService: container.read(syncServiceProvider),
        cache: container.read(pactDetailCacheProvider),
      );
      await breakService.startBreak(
        id: 'b1',
        pactId: 'pact-1',
        startDate: DateTime(2054, 1, 2),
        rationale: 'Travel',
        plannedEndDate: DateTime(2054, 1, 4),
        now: DateTime(2054, 1, 1, 12),
      );

      // No dashboard loads at all while the break is active or shortly after
      // it ends — the user simply doesn't open the app. Jump straight to day
      // 20, long after the break naturally elapsed, and open the app once.
      container.updateOverrides([
        todayProvider.overrideWithValue(DateTime(2054, 1, 20)),
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactBreakRepositoryProvider.overrideWithValue(breakRepo),
        notificationServiceProvider.overrideWithValue(notificationService),
        pactTransactionServiceProvider.overrideWithValue(transactionService),
      ]);
      await container.read(dashboardViewModelProvider.notifier).load();

      final scheduledIds = notificationService.scheduledReminders.map((r) => r.showup.id).toSet();
      // Showup that already existed at break-creation time (part of the
      // initial day1-11 window), scheduled well after the break ended.
      final preexistingPostBreakShowup = (await showupRepo.getShowupsForPact('pact-1'))
          .where((s) => s.scheduledAt.year == 2054 && s.scheduledAt.month == 1 && s.scheduledAt.day == 8)
          .single;

      expect(
        scheduledIds,
        contains(preexistingPostBreakShowup.id),
        reason: 'a showup outside the break window, generated before the break even started, must keep its reminder',
      );
    },
  );
}

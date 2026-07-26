import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_break_service.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';
import '../../../infrastructure/sync/fake_sync_service.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

Showup _showup(String id, DateTime scheduledAt, {ShowupStatus status = ShowupStatus.pending}) => Showup(
      id: id,
      pactId: 'p1',
      scheduledAt: scheduledAt,
      duration: const Duration(minutes: 10),
      status: status,
    );

PactBreak _pactBreak({
  String id = 'b1',
  String pactId = 'p1',
  DateTime? startDate,
  DateTime? plannedEndDate,
  DateTime? stoppedAt,
}) =>
    PactBreak(
      id: id,
      pactId: pactId,
      startDate: startDate ?? DateTime(2026, 3, 1),
      rationale: 'Recovering',
      plannedEndDate: plannedEndDate,
      stoppedAt: stoppedAt,
    );

void main() {
  late InMemoryPactBreakRepository breakRepo;
  late InMemoryShowupRepository showupRepo;
  late InMemoryPactRepository pactRepo;
  late FakeNotificationService notificationService;
  late ReminderSchedulingService reminderSchedulingService;
  late FakeSyncService syncService;
  late PactDetailCache cache;
  late PactBreakService service;

  setUp(() {
    breakRepo = InMemoryPactBreakRepository();
    showupRepo = InMemoryShowupRepository();
    pactRepo = InMemoryPactRepository([_pact]);
    notificationService = FakeNotificationService();
    reminderSchedulingService = ReminderSchedulingService(
      notificationService: notificationService,
      remoteConfig: FakeRemoteConfigService(),
      analytics: FakeAnalyticsService(),
      localePreference: FakeLocalePreferenceService(),
    );
    syncService = FakeSyncService();
    cache = PactDetailCache(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      pactBreakRepository: breakRepo,
      grouper: const PactTimelineGrouper(),
    );
    service = PactBreakService(
      pactBreakRepository: breakRepo,
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      reminderSchedulingService: reminderSchedulingService,
      syncService: syncService,
      cache: cache,
    );
  });

  group('PactBreakService.startBreak', () {
    test('persists a new break and returns it', () async {
      final result = await service.startBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 4, 1),
        rationale: 'Travel',
        plannedEndDate: DateTime(2026, 4, 10),
        now: DateTime(2026, 3, 15),
      );

      expect(result.id, 'b1');
      expect(result.rationale, 'Travel');
      final persisted = await breakRepo.getBreakById('b1');
      expect(persisted, isNotNull);
    });

    test('throws StateError when the pact already has an active break', () async {
      await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));

      expect(
        () => service.startBreak(
          id: 'b2',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 20),
          rationale: 'Another',
          now: DateTime(2026, 3, 15),
        ),
        throwsStateError,
      );
    });

    test('throws StateError when the pact has a scheduled (future-start) unresolved break', () async {
      await breakRepo.saveBreak(_pactBreak(startDate: DateTime(2026, 5, 1)));

      expect(
        () => service.startBreak(
          id: 'b2',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 20),
          rationale: 'Another',
          now: DateTime(2026, 3, 15),
        ),
        throwsStateError,
      );
    });

    test('allows starting a new break once the previous one was stopped', () async {
      await breakRepo.saveBreak(
        _pactBreak(plannedEndDate: DateTime(2026, 4, 10), stoppedAt: DateTime(2026, 3, 10)),
      );

      final result = await service.startBreak(
        id: 'b2',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 20),
        rationale: 'Another',
        now: DateTime(2026, 3, 15),
      );

      expect(result.id, 'b2');
    });

    test('allows starting a new break once the previous fixed-end break has elapsed', () async {
      await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 3, 5)));

      final result = await service.startBreak(
        id: 'b2',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 20),
        rationale: 'Another',
        now: DateTime(2026, 3, 15),
      );

      expect(result.id, 'b2');
    });

    test('throws ArgumentError when rationale is empty', () async {
      expect(
        () => service.startBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 4, 1),
          rationale: '',
          now: DateTime(2026, 3, 15),
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when rationale is only whitespace', () async {
      expect(
        () => service.startBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 4, 1),
          rationale: '   ',
          now: DateTime(2026, 3, 15),
        ),
        throwsArgumentError,
      );
    });

    test('uploads the new break via SyncService', () async {
      await service.startBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 4, 1),
        rationale: 'Travel',
        now: DateTime(2026, 3, 15),
      );
      await Future<void>.delayed(Duration.zero);

      expect(syncService.uploadedPactBreakIds, contains('b1'));
    });

    test('cancels reminders for pending showups falling inside the new window', () async {
      await showupRepo.saveShowup(_showup('s1', DateTime(2026, 4, 5, 8)));
      await showupRepo.saveShowup(_showup('s2', DateTime(2026, 5, 1, 8)));

      await service.startBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 4, 1),
        rationale: 'Travel',
        plannedEndDate: DateTime(2026, 4, 10),
        now: DateTime(2026, 3, 15),
      );

      expect(notificationService.cancelledShowupIds, equals(['s1']));
    });

    test('does not cancel reminders for a done showup inside the window', () async {
      await showupRepo.saveShowup(_showup('s1', DateTime(2026, 4, 5, 8), status: ShowupStatus.done));

      await service.startBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 4, 1),
        rationale: 'Travel',
        plannedEndDate: DateTime(2026, 4, 10),
        now: DateTime(2026, 3, 15),
      );

      expect(notificationService.cancelledShowupIds, isEmpty);
    });

    test('evicts the pact detail cache entry', () async {
      await cache.load('p1', now: DateTime(2026, 3, 15));
      expect(cache.peek('p1'), isNotNull);

      await service.startBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 4, 1),
        rationale: 'Travel',
        now: DateTime(2026, 3, 15),
      );

      expect(cache.peek('p1'), isNull);
    });
  });

  group('PactBreakService.stopBreak', () {
    test('stops an active break, setting stoppedAt', () async {
      await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));

      final result = await service.stopBreak('b1', now: DateTime(2026, 3, 20));

      expect(result.stoppedAt, DateTime(2026, 3, 20));
      final persisted = await breakRepo.getBreakById('b1');
      expect(persisted?.stoppedAt, DateTime(2026, 3, 20));
    });

    test('throws ArgumentError when no break with the given id exists', () async {
      expect(() => service.stopBreak('missing', now: DateTime(2026, 3, 20)), throwsArgumentError);
    });

    test('uploads the stopped break via SyncService', () async {
      await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));

      await service.stopBreak('b1', now: DateTime(2026, 3, 20));
      await Future<void>.delayed(Duration.zero);

      expect(syncService.uploadedPactBreakIds, contains('b1'));
    });

    test('evicts the pact detail cache entry', () async {
      await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));
      await cache.load('p1', now: DateTime(2026, 3, 15));
      expect(cache.peek('p1'), isNotNull);

      await service.stopBreak('b1', now: DateTime(2026, 3, 20));

      expect(cache.peek('p1'), isNull);
    });

    // HAB-195 WU3: auto-fail resumes "for free" because on-break state is
    // derived at read time, but reminder scheduling is a one-shot side effect
    // cancelled by startBreak — stopBreak must explicitly restore it.
    group('reminder rescheduling (HAB-195 WU3)', () {
      test('reschedules reminders for future showups released by the stop', () async {
        await pactRepo.updatePact(_pact.copyWith(reminderOffset: const Duration(minutes: 15)));
        await showupRepo.saveShowup(_showup('s-released', DateTime(2026, 4, 5, 8)));
        await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));

        await service.stopBreak('b1', now: DateTime(2026, 3, 20));

        expect(notificationService.scheduledReminders.map((r) => r.showup.id), contains('s-released'));
      });

      test('does not reschedule a showup that stays on break (scheduled at/before the stop instant)', () async {
        await pactRepo.updatePact(_pact.copyWith(reminderOffset: const Duration(minutes: 15)));
        await showupRepo.saveShowup(_showup('s-still-onbreak', DateTime(2026, 3, 18, 8)));
        await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));

        await service.stopBreak('b1', now: DateTime(2026, 3, 20));

        expect(notificationService.scheduledReminders, isEmpty);
      });

      test('does not reschedule a showup outside the break window in the first place', () async {
        await pactRepo.updatePact(_pact.copyWith(reminderOffset: const Duration(minutes: 15)));
        await showupRepo.saveShowup(_showup('s-never-onbreak', DateTime(2026, 5, 1, 8)));
        await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));

        await service.stopBreak('b1', now: DateTime(2026, 3, 20));

        expect(notificationService.scheduledReminders, isEmpty);
      });

      test('does not reschedule a done showup even if it falls in the released window', () async {
        await pactRepo.updatePact(_pact.copyWith(reminderOffset: const Duration(minutes: 15)));
        await showupRepo.saveShowup(_showup('s-done', DateTime(2026, 4, 5, 8), status: ShowupStatus.done));
        await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));

        await service.stopBreak('b1', now: DateTime(2026, 3, 20));

        expect(notificationService.scheduledReminders, isEmpty);
      });

      test('does not reschedule when the pact has no reminderOffset', () async {
        await showupRepo.saveShowup(_showup('s-no-offset', DateTime(2026, 4, 5, 8)));
        await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));

        await service.stopBreak('b1', now: DateTime(2026, 3, 20));

        expect(notificationService.scheduledReminders, isEmpty);
      });

      test('does not reschedule a released showup still covered by a second, unrelated break', () async {
        await pactRepo.updatePact(_pact.copyWith(reminderOffset: const Duration(minutes: 15)));
        await showupRepo.saveShowup(_showup('s-double-covered', DateTime(2026, 4, 5, 8)));
        await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));
        // A second, already-stopped break that still happens to cover 4/5 — simulates
        // break history overlap; the showup must remain unscheduled either way.
        await breakRepo.saveBreak(
          _pactBreak(
            id: 'b2',
            startDate: DateTime(2026, 4, 4),
            plannedEndDate: DateTime(2026, 4, 6),
            stoppedAt: DateTime(2026, 4, 6),
          ),
        );

        await service.stopBreak('b1', now: DateTime(2026, 3, 20));

        expect(notificationService.scheduledReminders, isEmpty);
      });
    });
  });

  group('PactBreakService.getActiveBreak', () {
    test('returns null when there are no breaks', () async {
      expect(await service.getActiveBreak('p1', now: DateTime(2026, 3, 15)), isNull);
    });

    test('returns the unresolved break when one exists', () async {
      await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10)));
      final result = await service.getActiveBreak('p1', now: DateTime(2026, 3, 15));
      expect(result?.id, 'b1');
    });

    test('returns null when the only break has been stopped', () async {
      await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 4, 10), stoppedAt: DateTime(2026, 3, 10)));
      expect(await service.getActiveBreak('p1', now: DateTime(2026, 3, 15)), isNull);
    });

    test("returns null once the only break's planned end has passed", () async {
      await breakRepo.saveBreak(_pactBreak(plannedEndDate: DateTime(2026, 3, 5)));
      expect(await service.getActiveBreak('p1', now: DateTime(2026, 3, 15)), isNull);
    });

    test('returns a scheduled (future-start) break too — it still blocks a new one', () async {
      await breakRepo.saveBreak(_pactBreak(startDate: DateTime(2026, 5, 1)));
      final result = await service.getActiveBreak('p1', now: DateTime(2026, 3, 15));
      expect(result?.id, 'b1');
    });
  });

  group('PactBreakService.getBreaksForPact', () {
    test('delegates to the repository', () async {
      await breakRepo.saveBreak(_pactBreak(id: 'b1', startDate: DateTime(2026, 3, 1)));
      await breakRepo.saveBreak(_pactBreak(id: 'b2', startDate: DateTime(2026, 5, 1)));

      final result = await service.getBreaksForPact('p1');

      expect(result.map((b) => b.id), containsAll(['b1', 'b2']));
    });
  });
}

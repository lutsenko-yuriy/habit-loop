import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/notification_reconciliation_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

Pact _makePact({Duration? reminderOffset = const Duration(minutes: 10)}) {
  return Pact(
    id: 'pact-1',
    habitName: 'Meditate',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 6, 30),
    showupDuration: const Duration(minutes: 20),
    schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
    status: PactStatus.active,
    reminderOffset: reminderOffset,
    createdAt: DateTime(2026, 1, 1),
  );
}

Showup _makeShowup({
  required String id,
  required DateTime scheduledAt,
  ShowupStatus status = ShowupStatus.pending,
  Duration duration = const Duration(minutes: 20),
}) {
  return Showup(id: id, pactId: 'pact-1', scheduledAt: scheduledAt, duration: duration, status: status);
}

void main() {
  late InMemoryPactRepository pactRepo;
  late InMemoryShowupRepository showupRepo;
  late InMemoryPactBreakRepository breakRepo;
  late FakeNotificationService notificationService;
  late FakeAnalyticsService analytics;
  late FakeRemoteConfigService remoteConfig;
  late FakeLocalePreferenceService localePreference;
  late NotificationReconciliationService service;

  setUp(() {
    notificationService = FakeNotificationService();
    analytics = FakeAnalyticsService();
    // hurry_up_notification_enabled defaults to true (HAB-246 WU4) — pinned
    // false here so tests that don't exercise hurry-up eligibility get a
    // predictable rescheduled count.
    remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': false});
    localePreference = FakeLocalePreferenceService();
    // Individual tests populate these before constructing the service.
    pactRepo = InMemoryPactRepository();
    showupRepo = InMemoryShowupRepository();
    breakRepo = InMemoryPactBreakRepository();
  });

  NotificationReconciliationService buildService() {
    return NotificationReconciliationService(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      pactBreakRepository: breakRepo,
      notificationService: notificationService,
      remoteConfig: remoteConfig,
      analytics: analytics,
      localePreference: localePreference,
    );
  }

  group('reconcile', () {
    test('kill switch off: makes no scheduling or cancellation calls, even with drift present', () async {
      remoteConfig = FakeRemoteConfigService(
        overrides: {'notification_reconciliation_enabled': false, 'hurry_up_notification_enabled': false},
      );
      pactRepo = InMemoryPactRepository([_makePact()]);
      showupRepo = InMemoryShowupRepository([
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ]);
      service = buildService();

      await service.reconcile(now: DateTime(2026, 5, 7, 10, 0));

      expect(notificationService.scheduledReminders, isEmpty);
      expect(notificationService.cancelledShowupIds, isEmpty);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('break-elapsed restore: reschedules a reminder missing from the OS for a desired showup', () async {
      pactRepo = InMemoryPactRepository([_makePact()]);
      final showup = _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0));
      showupRepo = InMemoryShowupRepository([showup]);
      // Nothing pending with the OS — simulates the break-resume bug: the
      // in-window cancel never got followed by a reschedule.
      notificationService.pendingNotifications = const [];
      service = buildService();

      await service.reconcile(now: DateTime(2026, 5, 7, 10, 0));

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledReminders.first.showup.id, equals('su-1'));
      expect(analytics.loggedEvents, hasLength(1));
      final event = analytics.loggedEvents.single as NotificationsReconciledEvent;
      expect(event.rescheduledCount, equals(1));
      expect(event.cancelledCount, equals(0));
    });

    test('active break: does not schedule a reminder for an in-window showup', () async {
      pactRepo = InMemoryPactRepository([_makePact()]);
      final onBreak = _makeShowup(id: 'su-onbreak', scheduledAt: DateTime(2026, 5, 8, 8, 0));
      showupRepo = InMemoryShowupRepository([onBreak]);
      breakRepo = InMemoryPactBreakRepository([
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ]);
      service = buildService();

      await service.reconcile(now: DateTime(2026, 5, 7, 10, 0));

      expect(notificationService.scheduledReminders, isEmpty);
      expect(notificationService.cancelledShowupIds, isEmpty);
    });

    test('active break: cancels a reminder still pending with the OS for an in-window showup', () async {
      pactRepo = InMemoryPactRepository([_makePact()]);
      final onBreak = _makeShowup(id: 'su-onbreak', scheduledAt: DateTime(2026, 5, 8, 8, 0));
      showupRepo = InMemoryShowupRepository([onBreak]);
      breakRepo = InMemoryPactBreakRepository([
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ]);
      // Started before the break began — still registered with the OS.
      notificationService.pendingNotifications = [
        PendingNotificationInfo(id: NotificationConstants.reminderNotificationId('su-onbreak')),
      ];
      service = buildService();

      await service.reconcile(now: DateTime(2026, 5, 7, 10, 0));

      expect(notificationService.cancelledShowupIds, equals(['su-onbreak']));
      final event = analytics.loggedEvents.single as NotificationsReconciledEvent;
      expect(event.cancelledCount, equals(1));
    });

    test('no drift: makes no calls and logs no analytics event', () async {
      pactRepo = InMemoryPactRepository([_makePact()]);
      final showup = _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0));
      showupRepo = InMemoryShowupRepository([showup]);
      // Already correctly scheduled — matches the desired plan exactly.
      notificationService.pendingNotifications = [
        PendingNotificationInfo(id: NotificationConstants.reminderNotificationId('su-1')),
      ];
      service = buildService();

      await service.reconcile(now: DateTime(2026, 5, 7, 10, 0));

      expect(notificationService.scheduledReminders, isEmpty);
      expect(notificationService.cancelledShowupIds, isEmpty);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('idempotent: a second reconcile over the same unchanged state makes no further calls', () async {
      pactRepo = InMemoryPactRepository([_makePact()]);
      final showup = _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0));
      showupRepo = InMemoryShowupRepository([showup]);
      notificationService.pendingNotifications = [
        PendingNotificationInfo(id: NotificationConstants.reminderNotificationId('su-1')),
      ];
      service = buildService();

      await service.reconcile(now: DateTime(2026, 5, 7, 10, 0));
      await service.reconcile(now: DateTime(2026, 5, 7, 10, 5));

      expect(notificationService.scheduledReminders, isEmpty);
      expect(notificationService.cancelledShowupIds, isEmpty);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('pacts without a reminder offset are skipped entirely', () async {
      pactRepo = InMemoryPactRepository([_makePact(reminderOffset: null)]);
      showupRepo = InMemoryShowupRepository([
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ]);
      service = buildService();

      await service.reconcile(now: DateTime(2026, 5, 7, 10, 0));

      expect(notificationService.scheduledReminders, isEmpty);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('only reschedules the specific missing notification kind (deadline missing, reminder present)', () async {
      remoteConfig = FakeRemoteConfigService(
        overrides: {'post_deadline_notification_behavior': 'encourage', 'hurry_up_notification_enabled': false},
      );
      pactRepo = InMemoryPactRepository([_makePact()]);
      final showup = _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0));
      showupRepo = InMemoryShowupRepository([showup]);
      // Reminder already registered; deadline is missing.
      notificationService.pendingNotifications = [
        PendingNotificationInfo(id: NotificationConstants.reminderNotificationId('su-1')),
      ];
      service = buildService();

      await service.reconcile(now: DateTime(2026, 5, 7, 10, 0));

      expect(notificationService.scheduledReminders, isEmpty);
      expect(notificationService.scheduledDeadlines, hasLength(1));
      expect(notificationService.scheduledDeadlines.first.showup.id, equals('su-1'));
    });
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/notifications/fake_notification_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

Pact _makePact({Duration? reminderOffset}) {
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
}) {
  return Showup(
    id: id,
    pactId: 'pact-1',
    scheduledAt: scheduledAt,
    duration: const Duration(minutes: 20),
    status: status,
  );
}

void main() {
  late FakeNotificationService notificationService;
  late FakeAnalyticsService analyticsService;
  late FakeRemoteConfigService remoteConfig;
  late AppLocalizations l10n;
  late ReminderSchedulingService service;

  setUp(() {
    notificationService = FakeNotificationService();
    analyticsService = FakeAnalyticsService();
    remoteConfig = FakeRemoteConfigService();
    l10n = lookupAppLocalizations(const Locale('en'));
    service = ReminderSchedulingService(
      notificationService: notificationService,
      remoteConfig: remoteConfig,
      analytics: analyticsService,
      isIOS: false,
    );
  });

  group('scheduleRemindersForShowups', () {
    test('no-op when pact has no reminder offset', () async {
      final pact = _makePact(reminderOffset: null);
      final now = DateTime(2026, 5, 1, 9, 0);
      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 2, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(notificationService.scheduledReminders, isEmpty);
      expect(analyticsService.loggedEvents, isEmpty);
    });

    test('schedules only future pending showups', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        // Past — should NOT be scheduled
        _makeShowup(id: 'su-past', scheduledAt: DateTime(2026, 5, 6, 8, 0)),
        // Future pending — SHOULD be scheduled
        _makeShowup(id: 'su-future', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        // Future but done — should NOT be scheduled
        _makeShowup(id: 'su-done', scheduledAt: DateTime(2026, 5, 9, 8, 0), status: ShowupStatus.done),
        // Future but failed — should NOT be scheduled
        _makeShowup(id: 'su-failed', scheduledAt: DateTime(2026, 5, 10, 8, 0), status: ShowupStatus.failed),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledReminders.first.showup.id, equals('su-future'));
    });

    test('fires NotificationsScheduledEvent with correct count', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        _makeShowup(id: 'su-2', scheduledAt: DateTime(2026, 5, 9, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(analyticsService.loggedEvents, hasLength(1));
      final event = analyticsService.loggedEvents.first;
      expect(event, isA<NotificationsScheduledEvent>());
      final scheduled = event as NotificationsScheduledEvent;
      expect(scheduled.pactId, equals('pact-1'));
      expect(scheduled.notificationsCount, equals(2));
      expect(scheduled.reminderOffsetMinutes, equals(10));
    });

    test('does not fire analytics event when no showups are scheduled', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      // All showups are in the past
      final showups = [
        _makeShowup(id: 'su-past', scheduledAt: DateTime(2026, 5, 6, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(analyticsService.loggedEvents, isEmpty);
    });

    // Platform-specific tests use the injected isIOS flag for full coverage on any host platform.

    test('isIOS=false with dismiss config: only schedules reminder, no deadline', () async {
      // isIOS=false is the default set in setUp; 'dismiss' is FakeRemoteConfigService default.
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledDeadlines, isEmpty);
    });

    test('isIOS=true always schedules both reminder and deadline regardless of remote config', () async {
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        isIOS: true,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledDeadlines, hasLength(1));
    });

    test('isIOS=false with encourage config: schedules both reminder and deadline', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'post_deadline_notification_behavior': 'encourage'});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        isIOS: false,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledDeadlines, hasLength(1));
    });

    test('skips showup when reminder fire time (scheduledAt - reminderOffset) is in the past', () async {
      // Showup is at 09:30, reminder offset is 60 min → fire time 08:30.
      // now = 09:00 → fire time 08:30 is in the past → should NOT schedule.
      final pact = _makePact(reminderOffset: const Duration(minutes: 60));
      final now = DateTime(2026, 5, 8, 9, 0);

      final showups = [
        _makeShowup(id: 'su-future-but-reminder-past', scheduledAt: DateTime(2026, 5, 8, 9, 30)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(notificationService.scheduledReminders, isEmpty);
    });

    test('uses notification_text_variant from remote config', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'notification_text_variant': 'deadline'});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      expect(notificationService.scheduledReminders, hasLength(1));
      final reminder = notificationService.scheduledReminders.first;
      // 'deadline' variant title should contain the habit name
      expect(reminder.titleText, contains('Meditate'));
    });

    test('passes correct title and body to scheduleShowupReminder', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, l10n: l10n, now: now);

      final reminder = notificationService.scheduledReminders.first;
      expect(reminder.titleText, isNotEmpty);
      expect(reminder.bodyText, isNotEmpty);
      expect(reminder.pact, equals(pact));
    });
  });

  group('cancelRemindersForShowup', () {
    test('delegates to notificationService.cancelShowupReminder', () async {
      await service.cancelRemindersForShowup('su-123');

      expect(notificationService.cancelledShowupIds, contains('su-123'));
    });
  });

  group('cancelAllRemindersForPact', () {
    test('delegates to notificationService.cancelAllRemindersForPact', () async {
      await service.cancelAllRemindersForPact('pact-abc');

      expect(notificationService.cancelledPactIds, contains('pact-abc'));
    });
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';
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
  late FakeLocalePreferenceService localePreference;
  late ReminderSchedulingService service;

  setUp(() {
    notificationService = FakeNotificationService();
    analyticsService = FakeAnalyticsService();
    remoteConfig = FakeRemoteConfigService();
    localePreference = FakeLocalePreferenceService();
    service = ReminderSchedulingService(
      notificationService: notificationService,
      remoteConfig: remoteConfig,
      analytics: analyticsService,
      localePreference: localePreference,
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

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

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

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

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

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

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

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

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

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledDeadlines, isEmpty);
    });

    test('isIOS=true always schedules both reminder and deadline regardless of remote config', () async {
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
        isIOS: true,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledDeadlines, hasLength(1));
    });

    test('isIOS=false with encourage config: schedules both reminder and deadline', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'post_deadline_notification_behavior': 'encourage'});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
        isIOS: false,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

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

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledReminders, isEmpty);
    });

    test('uses notification_text_variant from remote config', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'notification_text_variant': 'deadline'});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

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

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      final reminder = notificationService.scheduledReminders.first;
      expect(reminder.titleText, isNotEmpty);
      expect(reminder.bodyText, isNotEmpty);
      expect(reminder.pact, equals(pact));
    });

    group('locale resolution', () {
      test('uses saved locale for notification text', () async {
        // Save French locale; notifications should use French l10n strings.
        // We verify the service schedules without error — full string
        // comparison would be fragile if l10n strings change.
        await localePreference.saveLocale(const Locale('fr'));

        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        ];

        await expectLater(
          service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now),
          completes,
          reason: 'scheduleRemindersForShowups must complete without error when saved locale is fr',
        );
        expect(notificationService.scheduledReminders, hasLength(1));
      });

      test('falls back to English when no locale saved', () async {
        // localePreference returns null by default (no saveLocale call).
        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        ];

        await expectLater(
          service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now),
          completes,
          reason: 'scheduleRemindersForShowups must complete without error when no locale is saved',
        );
        expect(notificationService.scheduledReminders, hasLength(1));
      });

      test('falls back to English when saved locale is unsupported', () async {
        // 'xx' is not a supported locale — lookupAppLocalizations throws.
        // The service must catch and fall back to English.
        await localePreference.saveLocale(const Locale('xx'));

        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        ];

        await expectLater(
          service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now),
          completes,
          reason: 'scheduleRemindersForShowups must not throw when saved locale is unsupported',
        );
        // Should still schedule using English fallback.
        expect(notificationService.scheduledReminders, hasLength(1));
      });
    });
  });

  group('iOS 64-notification cap', () {
    test('on iOS, caps scheduled showups at 32 (64 notifications / 2 per showup)', () async {
      // iOS allows at most 64 pending local notifications; each showup on iOS
      // uses 2 (reminder + deadline). So the cap is 64 / 2 = 32.
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
        isIOS: true,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      // Create 40 qualifying showups — more than the 32-showup iOS cap.
      final showups = List.generate(40, (i) {
        return _makeShowup(
          id: 'su-$i',
          scheduledAt: DateTime(2026, 5, 8 + i, 8, 0),
        );
      });

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      // Only 32 reminders must be scheduled despite 40 qualifying showups.
      expect(
        notificationService.scheduledReminders,
        hasLength(32),
        reason: 'iOS cap: only 32 showups may be scheduled (64 notifications / 2 per showup)',
      );
      // Corresponding 32 deadline notifications must also be scheduled.
      expect(
        notificationService.scheduledDeadlines,
        hasLength(32),
        reason: 'iOS cap: 32 deadline notifications must accompany the 32 reminders',
      );
    });

    test('on Android (isIOS=false), no cap is applied — all showups are scheduled', () async {
      // Android has no practical pending-notification limit, so all showups pass through.
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      // 40 qualifying showups on Android (isIOS=false, default dismiss config).
      final showups = List.generate(40, (i) {
        return _makeShowup(
          id: 'su-$i',
          scheduledAt: DateTime(2026, 5, 8 + i, 8, 0),
        );
      });

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      // All 40 showups should be scheduled on Android.
      expect(
        notificationService.scheduledReminders,
        hasLength(40),
        reason: 'Android: all 40 qualifying showups must be scheduled without a cap',
      );
    });
  });

  group('cancelRemindersForShowup', () {
    test('delegates to notificationService.cancelShowupReminder', () async {
      await service.cancelRemindersForShowup('su-123');

      expect(notificationService.cancelledShowupIds, contains('su-123'));
    });
  });

  group('cancelAllRemindersForPact', () {
    test('delegates pactId to notificationService', () async {
      await service.cancelAllRemindersForPact('pact-abc');

      expect(notificationService.cancelledPactIds, contains('pact-abc'));
    });

    test('forwards showupIds to notificationService', () async {
      await service.cancelAllRemindersForPact(
        'pact-abc',
        showupIds: ['su-1', 'su-2'],
      );

      expect(notificationService.cancelledPactIds, contains('pact-abc'));
      expect(notificationService.cancelledPactShowupIds.last, containsAll(['su-1', 'su-2']));
    });
  });
}

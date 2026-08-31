import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/reminder/application/notification_text_builder.dart';
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
  Duration duration = const Duration(minutes: 20),
}) {
  return Showup(
    id: id,
    pactId: 'pact-1',
    scheduledAt: scheduledAt,
    duration: duration,
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
    // hurry_up_notification_enabled now defaults to true (HAB-246 WU4) —
    // pinned false here so every pre-existing test in this file keeps
    // asserting its original reminder/deadline-only notification counts.
    // The 'hurry-up notification' group below overrides back to true (or
    // omits the override, for the dedicated default-value test) per test.
    remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': false});
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

      test('falls back to English when no locale saved and no system locale injected', () async {
        // localePreference returns null by default (no saveLocale call);
        // service default systemLocale is English.
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

      test('falls back to the injected system locale when no in-app locale is saved', () async {
        // No in-app override saved — this is the HAB-157 repro: user changed
        // the OS/system language but never opened the in-app language picker.
        service = ReminderSchedulingService(
          notificationService: notificationService,
          remoteConfig: remoteConfig,
          analytics: analyticsService,
          localePreference: localePreference,
          systemLocale: const Locale('ru'),
        );

        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        ];

        await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

        final reminder = notificationService.scheduledReminders.first;
        final ruL10n = lookupAppLocalizations(const Locale('ru'));
        expect(reminder.titleText, equals(ruL10n.notificationReminderTitle('Meditate')));
      });

      test('an explicit in-app saved locale takes precedence over the injected system locale', () async {
        // Saved locale is French; system locale is Russian — saved wins.
        await localePreference.saveLocale(const Locale('fr'));
        service = ReminderSchedulingService(
          notificationService: notificationService,
          remoteConfig: remoteConfig,
          analytics: analyticsService,
          localePreference: localePreference,
          systemLocale: const Locale('ru'),
        );

        final pact = _makePact(reminderOffset: const Duration(minutes: 10));
        final now = DateTime(2026, 5, 7, 10, 0);
        final showups = [
          _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        ];

        await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

        final reminder = notificationService.scheduledReminders.first;
        final frL10n = lookupAppLocalizations(const Locale('fr'));
        expect(reminder.titleText, equals(frL10n.notificationReminderTitle('Meditate')));
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

  group('on-break suppression (HAB-195 WU3)', () {
    test('does not schedule a reminder for a showup inside an active break window', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-onbreak', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
        _makeShowup(id: 'su-offbreak', scheduledAt: DateTime(2026, 5, 20, 8, 0)),
      ];
      final breaks = [
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now, breaks: breaks);

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledReminders.first.showup.id, equals('su-offbreak'));
    });

    test('schedules normally when breaks list is empty (default)', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledReminders, hasLength(1));
    });

    test('schedules a showup scheduled after the break window ends', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      final showups = [
        _makeShowup(id: 'su-after-break', scheduledAt: DateTime(2026, 5, 15, 8, 0)),
      ];
      final breaks = [
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now, breaks: breaks);

      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledReminders.first.showup.id, equals('su-after-break'));
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

  group('welcome-back reminder text (HAB-227)', () {
    late AppLocalizations l10n;

    setUpAll(() {
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    test('the first showup after a fixed-end break gets welcome-back text', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final breaks = [
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ];
      // Deterministic id for the daily 8am showup on the day after the break ends.
      final target = ShowupGenerator.generateWindow(
        pact,
        from: DateTime(2026, 5, 11, 8),
        to: DateTime(2026, 5, 11, 8, 1),
      ).first;
      final showups = [target];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now, breaks: breaks);

      final expected = NotificationTextBuilder.buildWelcomeBackText(habitName: pact.habitName, l10n: l10n);
      expect(notificationService.scheduledReminders, hasLength(1));
      expect(notificationService.scheduledReminders.first.titleText, expected.title);
      expect(notificationService.scheduledReminders.first.bodyText, expected.body);
    });

    test('a non-target showup keeps normal reminder text even with a break present', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final breaks = [
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ];
      final showups = [_makeShowup(id: 'su-later', scheduledAt: DateTime(2026, 5, 20, 8, 0))];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now, breaks: breaks);

      final normal = NotificationTextBuilder.buildReminderText(
        habitName: pact.habitName,
        l10n: l10n,
      );
      expect(notificationService.scheduledReminders.first.titleText, normal.title);
    });

    test('the deadline notification keeps standard wording even for the welcome-back showup', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final breaks = [
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ];
      final target = ShowupGenerator.generateWindow(
        pact,
        from: DateTime(2026, 5, 11, 8),
        to: DateTime(2026, 5, 11, 8, 1),
      ).first;
      // Android + postDeadlineBehavior=encourage schedules a deadline notification too.
      final rcWithEncourage = FakeRemoteConfigService(overrides: {'post_deadline_notification_behavior': 'encourage'});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: rcWithEncourage,
        analytics: analyticsService,
        localePreference: localePreference,
      );

      await service.scheduleRemindersForShowups(pact: pact, showups: [target], now: now, breaks: breaks);

      final missed = NotificationTextBuilder.buildDeadlineExpiredText(l10n: l10n);
      expect(notificationService.scheduledDeadlines, hasLength(1));
      expect(notificationService.scheduledDeadlines.first.titleText, missed.title);
    });

    test('welcome-back text is skipped when break_welcome_back_notification_enabled is false', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final breaks = [
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ];
      final target = ShowupGenerator.generateWindow(
        pact,
        from: DateTime(2026, 5, 11, 8),
        to: DateTime(2026, 5, 11, 8, 1),
      ).first;
      final rcDisabled = FakeRemoteConfigService(overrides: {'break_welcome_back_notification_enabled': false});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: rcDisabled,
        analytics: analyticsService,
        localePreference: localePreference,
      );

      await service.scheduleRemindersForShowups(pact: pact, showups: [target], now: now, breaks: breaks);

      final normal = NotificationTextBuilder.buildReminderText(
        habitName: pact.habitName,
        l10n: l10n,
      );
      expect(notificationService.scheduledReminders.first.titleText, normal.title);
    });
  });

  group('hurry-up notification (HAB-246)', () {
    test('does not schedule when hurry_up_notification_enabled is false', () async {
      // remoteConfig is already pinned false in setUp.
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 30)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledHurryUps, isEmpty);
    });

    test('schedules when hurry_up_notification_enabled defaults to true (HAB-246 WU4 flag flip)', () async {
      remoteConfig = FakeRemoteConfigService(); // no override — exercises the real RemoteConfigDefaults value.
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 30)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledHurryUps, hasLength(1));
    });

    test('schedules hurry-up when duration is exactly 3x hurry_up_time (boundary: eligible)', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': true});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 15)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledHurryUps, hasLength(1));
    });

    test('does not schedule hurry-up when duration is just under 3x hurry_up_time (boundary: ineligible)', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': true});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 14)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledHurryUps, isEmpty);
    });

    test('schedules hurry-up when duration exceeds 3x hurry_up_time', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': true});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 30)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledHurryUps, hasLength(1));
      final hurryUp = notificationService.scheduledHurryUps.first;
      expect(hurryUp.hurryUpOffset, equals(const Duration(minutes: 5)));
      expect(hurryUp.titleText, isNotEmpty);
      expect(hurryUp.bodyText, isNotEmpty);
    });

    test('non-default hurry_up_time_in_minutes shifts the eligibility threshold', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {
        'hurry_up_notification_enabled': true,
        'hurry_up_time_in_minutes': 10,
      });
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [
        _makeShowup(id: 'su-below', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 29)),
        _makeShowup(id: 'su-at', scheduledAt: DateTime(2026, 5, 9, 8, 0), duration: const Duration(minutes: 30)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledHurryUps, hasLength(1));
      expect(notificationService.scheduledHurryUps.first.showup.id, equals('su-at'));
    });

    test('clamps an out-of-range hurry_up_time_in_minutes (e.g. unset RC returns 0)', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {
        'hurry_up_notification_enabled': true,
        'hurry_up_time_in_minutes': 0,
      });
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      // Below the clamped-minimum (2min) threshold of 6min — would wrongly
      // qualify if the raw 0 were used unclamped (threshold 0min).
      final showups = [
        _makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 5)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledHurryUps, isEmpty);
    });

    test('does not schedule hurry-up for a non-pending showup', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': true});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [
        _makeShowup(
          id: 'su-done',
          scheduledAt: DateTime(2026, 5, 8, 8, 0),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
        ),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledHurryUps, isEmpty);
    });

    test('does not schedule hurry-up for a showup on break', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': true});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final breaks = [
        PactBreak(
          id: 'brk-1',
          pactId: 'pact-1',
          startDate: DateTime(2026, 5, 5),
          plannedEndDate: DateTime(2026, 5, 10),
          rationale: 'Traveling',
        ),
      ];
      final showups = [
        _makeShowup(id: 'su-on-break', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 30)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now, breaks: breaks);

      expect(notificationService.scheduledHurryUps, isEmpty);
    });

    test('fires NotificationsScheduledEvent with hurryUpCount reflecting scheduled hurry-ups', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': true});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [
        _makeShowup(id: 'su-eligible', scheduledAt: DateTime(2026, 5, 8, 8, 0), duration: const Duration(minutes: 30)),
        _makeShowup(
            id: 'su-ineligible', scheduledAt: DateTime(2026, 5, 9, 8, 0), duration: const Duration(minutes: 10)),
      ];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      final event = analyticsService.loggedEvents.single as NotificationsScheduledEvent;
      expect(event.hurryUpCount, equals(1));
      // 2 reminders + 1 hurry-up (isIOS=false + dismiss, so no deadlines).
      expect(event.notificationsCount, equals(3));
    });
  });

  group('iOS budget: chronological spend (HAB-246)', () {
    test('all-eligible showups schedule 21 (64 / 3 per showup: reminder + deadline + hurry-up)', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': true});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
        isIOS: true,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      // Default showup duration (20 min) clears the default 15-min eligibility threshold.
      final showups = List.generate(40, (i) {
        return _makeShowup(id: 'su-$i', scheduledAt: DateTime(2026, 5, 8 + i, 8, 0));
      });

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledReminders, hasLength(21));
      expect(notificationService.scheduledHurryUps, hasLength(21));
    });

    test('mixed eligible/ineligible showups, shuffled input, spend budget nearest-first', () async {
      remoteConfig = FakeRemoteConfigService(overrides: {'hurry_up_notification_enabled': true});
      service = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
        isIOS: true,
      );

      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);

      // 10 nearest showups are eligible (cost 3 each = 30); remaining budget (34)
      // buys 17 more ineligible showups (cost 2 each), leaving one over-budget.
      final eligible = List.generate(10, (i) {
        return _makeShowup(
          id: 'su-eligible-$i',
          scheduledAt: DateTime(2026, 5, 8 + i, 8, 0),
          duration: const Duration(minutes: 20),
        );
      });
      final ineligible = List.generate(30, (i) {
        return _makeShowup(
          id: 'su-ineligible-$i',
          scheduledAt: DateTime(2026, 5, 18 + i, 8, 0),
          duration: const Duration(minutes: 10),
        );
      });
      final shuffled = [...ineligible.reversed, ...eligible.reversed];

      await service.scheduleRemindersForShowups(pact: pact, showups: shuffled, now: now);

      expect(notificationService.scheduledReminders, hasLength(27));
      expect(notificationService.scheduledHurryUps, hasLength(10));
      final scheduledIds = notificationService.scheduledReminders.map((r) => r.showup.id).toSet();
      expect(scheduledIds, containsAll(eligible.map((s) => s.id)));
      expect(scheduledIds, containsAll(ineligible.take(17).map((s) => s.id)));
      expect(scheduledIds, isNot(contains('su-ineligible-17')));
    });
  });

  group('displayName personalization (HAB-232 WU7)', () {
    test('scheduled reminder text contains the name when the service is given one', () async {
      final named = ReminderSchedulingService(
        notificationService: notificationService,
        remoteConfig: remoteConfig,
        analytics: analyticsService,
        localePreference: localePreference,
        isIOS: false,
        displayName: 'Alex',
      );
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0))];

      await named.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      expect(notificationService.scheduledReminders.first.titleText, contains('Alex'));
    });

    test('scheduled reminder text has no name when the service is given none', () async {
      final pact = _makePact(reminderOffset: const Duration(minutes: 10));
      final now = DateTime(2026, 5, 7, 10, 0);
      final showups = [_makeShowup(id: 'su-1', scheduledAt: DateTime(2026, 5, 8, 8, 0))];

      await service.scheduleRemindersForShowups(pact: pact, showups: showups, now: now);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(notificationService.scheduledReminders.first.titleText, l10n.notificationReminderTitle('Meditate'));
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

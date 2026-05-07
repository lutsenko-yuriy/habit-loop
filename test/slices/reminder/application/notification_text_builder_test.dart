import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/reminder/application/notification_text_builder.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  group('NotificationTextBuilder.buildReminderText', () {
    final scheduledAt = DateTime(2026, 6, 15, 10, 0); // 10:00 AM
    const showupDuration = Duration(minutes: 30);
    const habitName = 'Meditate';

    test('control variant returns reminder title and body', () {
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'control',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: showupDuration,
        l10n: l10n,
      );

      expect(result.title, isNotEmpty);
      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('deadline variant title contains habit name', () {
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'deadline',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: showupDuration,
        l10n: l10n,
      );

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
      // Body should show the close time (10:00 + 30min = 10:30)
      expect(result.body, contains('10:30'));
    });

    test('time_limit variant title contains habit name', () {
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'time_limit',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: showupDuration,
        l10n: l10n,
      );

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
      // 30 minutes duration should appear in body
      expect(result.body, contains('30'));
    });

    test('time_limit with 1h duration shows hours format', () {
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'time_limit',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: const Duration(hours: 1),
        l10n: l10n,
      );

      expect(result.body, contains('1'));
    });

    test('time_limit with 1h 30min duration shows both hours and minutes', () {
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'time_limit',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: const Duration(hours: 1, minutes: 30),
        l10n: l10n,
      );

      expect(result.body, contains('1'));
      expect(result.body, contains('30'));
    });

    test('unknown variant falls back to control behavior', () {
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'unknown_variant',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: showupDuration,
        l10n: l10n,
      );

      // Falls back to control — title contains habit name, body is non-empty
      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('works in French locale', () {
      final frL10n = lookupAppLocalizations(const Locale('fr'));
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'control',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: showupDuration,
        l10n: frL10n,
      );

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    test('works in German locale', () {
      final deL10n = lookupAppLocalizations(const Locale('de'));
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'control',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: showupDuration,
        l10n: deL10n,
      );

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    test('works in Russian locale', () {
      final ruL10n = lookupAppLocalizations(const Locale('ru'));
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'control',
        habitName: habitName,
        scheduledAt: scheduledAt,
        showupDuration: showupDuration,
        l10n: ruL10n,
      );

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    test('deadline body formats close time correctly for midnight crossover', () {
      // Scheduled at 23:45, 30min duration -> closes at 00:15
      final lateScheduledAt = DateTime(2026, 6, 15, 23, 45);
      final result = NotificationTextBuilder.buildReminderText(
        variant: 'deadline',
        habitName: habitName,
        scheduledAt: lateScheduledAt,
        showupDuration: const Duration(minutes: 30),
        l10n: l10n,
      );

      expect(result.body, contains('00:15'));
    });
  });

  group('NotificationTextBuilder.buildDeadlineExpiredText', () {
    test('returns non-empty title and body', () {
      final result = NotificationTextBuilder.buildDeadlineExpiredText(l10n: l10n);

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    test('works in French locale', () {
      final frL10n = lookupAppLocalizations(const Locale('fr'));
      final result = NotificationTextBuilder.buildDeadlineExpiredText(l10n: frL10n);

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    test('works in German locale', () {
      final deL10n = lookupAppLocalizations(const Locale('de'));
      final result = NotificationTextBuilder.buildDeadlineExpiredText(l10n: deL10n);

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    test('works in Russian locale', () {
      final ruL10n = lookupAppLocalizations(const Locale('ru'));
      final result = NotificationTextBuilder.buildDeadlineExpiredText(l10n: ruL10n);

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });
  });
}

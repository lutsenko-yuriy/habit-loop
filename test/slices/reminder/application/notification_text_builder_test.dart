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
    const habitName = 'Meditate';

    test('returns reminder title and body', () {
      final result = NotificationTextBuilder.buildReminderText(habitName: habitName, l10n: l10n);

      expect(result.title, isNotEmpty);
      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('works in French locale', () {
      final frL10n = lookupAppLocalizations(const Locale('fr'));
      final result = NotificationTextBuilder.buildReminderText(habitName: habitName, l10n: frL10n);

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    test('works in German locale', () {
      final deL10n = lookupAppLocalizations(const Locale('de'));
      final result = NotificationTextBuilder.buildReminderText(habitName: habitName, l10n: deL10n);

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    test('works in Russian locale', () {
      final ruL10n = lookupAppLocalizations(const Locale('ru'));
      final result = NotificationTextBuilder.buildReminderText(habitName: habitName, l10n: ruL10n);

      expect(result.title, isNotEmpty);
      expect(result.body, isNotEmpty);
    });

    group('displayName personalization (HAB-232 WU7)', () {
      test('title contains the name when one is given', () {
        final result = NotificationTextBuilder.buildReminderText(
          habitName: habitName,
          l10n: l10n,
          displayName: 'Alex',
        );

        expect(result.title, contains('Alex'));
        expect(result.title, contains(habitName));
      });

      test('title has no name when displayName is null', () {
        final result = NotificationTextBuilder.buildReminderText(habitName: habitName, l10n: l10n);

        expect(result.title, l10n.notificationReminderTitle(habitName));
      });
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

    // No displayName parameter here at all (HAB-232 WU7 review) — a missed
    // showup reads better as neutral, matter-of-fact copy than a name-led one.
  });

  group('NotificationTextBuilder.buildWelcomeBackText', () {
    const habitName = 'Meditate';

    test('title contains the habit name', () {
      final result = NotificationTextBuilder.buildWelcomeBackText(habitName: habitName, l10n: l10n);

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('works in French locale', () {
      final frL10n = lookupAppLocalizations(const Locale('fr'));
      final result = NotificationTextBuilder.buildWelcomeBackText(habitName: habitName, l10n: frL10n);

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('works in German locale', () {
      final deL10n = lookupAppLocalizations(const Locale('de'));
      final result = NotificationTextBuilder.buildWelcomeBackText(habitName: habitName, l10n: deL10n);

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('works in Russian locale', () {
      final ruL10n = lookupAppLocalizations(const Locale('ru'));
      final result = NotificationTextBuilder.buildWelcomeBackText(habitName: habitName, l10n: ruL10n);

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('title contains the name when one is given', () {
      final result =
          NotificationTextBuilder.buildWelcomeBackText(habitName: habitName, l10n: l10n, displayName: 'Alex');

      expect(result.title, contains('Alex'));
      expect(result.title, contains(habitName));
    });

    test('title has no name when displayName is null', () {
      final result = NotificationTextBuilder.buildWelcomeBackText(habitName: habitName, l10n: l10n);

      expect(result.title, l10n.notificationWelcomeBackTitle(habitName));
    });
  });

  group('NotificationTextBuilder.buildHurryUpText', () {
    const habitName = 'Meditate';

    test('title contains the habit name', () {
      final result = NotificationTextBuilder.buildHurryUpText(habitName: habitName, l10n: l10n);

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('works in French locale', () {
      final frL10n = lookupAppLocalizations(const Locale('fr'));
      final result = NotificationTextBuilder.buildHurryUpText(habitName: habitName, l10n: frL10n);

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('works in German locale', () {
      final deL10n = lookupAppLocalizations(const Locale('de'));
      final result = NotificationTextBuilder.buildHurryUpText(habitName: habitName, l10n: deL10n);

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('works in Russian locale', () {
      final ruL10n = lookupAppLocalizations(const Locale('ru'));
      final result = NotificationTextBuilder.buildHurryUpText(habitName: habitName, l10n: ruL10n);

      expect(result.title, contains(habitName));
      expect(result.body, isNotEmpty);
    });

    test('title contains the name when one is given', () {
      final result = NotificationTextBuilder.buildHurryUpText(habitName: habitName, l10n: l10n, displayName: 'Alex');

      expect(result.title, contains('Alex'));
      expect(result.title, contains(habitName));
    });

    test('title has no name when displayName is null', () {
      final result = NotificationTextBuilder.buildHurryUpText(habitName: habitName, l10n: l10n);

      expect(result.title, l10n.notificationHurryUpTitle(habitName));
    });
  });
}

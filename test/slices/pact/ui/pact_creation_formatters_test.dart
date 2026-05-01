import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';

/// Pumps a trivial widget tree so that [AppLocalizations.of] and [Localizations.localeOf]
/// resolve during tests.
Future<(BuildContext, AppLocalizations)> _pumpLocalised(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return (capturedContext, AppLocalizations.of(capturedContext)!);
}

void main() {
  group('formatPactDate', () {
    testWidgets('formats a date using the current locale (en)', (tester) async {
      final (ctx, _) = await _pumpLocalised(tester);
      final text = formatPactDate(ctx, DateTime(2026, 3, 30));
      expect(text, '3/30/2026');
    });

    testWidgets('formats a date using the current locale (fr)', (tester) async {
      final (ctx, _) = await _pumpLocalised(tester, locale: const Locale('fr'));
      final text = formatPactDate(ctx, DateTime(2026, 3, 30));
      expect(text, '30/03/2026');
    });
  });

  group('scheduleDescription', () {
    testWidgets('returns empty string when schedule is null', (tester) async {
      final (ctx, l10n) = await _pumpLocalised(tester);
      expect(scheduleDescription(ctx, l10n, null), '');
    });

    testWidgets('describes DailySchedule with time @ HH:mm', (tester) async {
      final (ctx, l10n) = await _pumpLocalised(tester);
      final text = scheduleDescription(
        ctx,
        l10n,
        const DailySchedule(timeOfDay: Duration(hours: 7, minutes: 30)),
      );
      // Locale-sensitive time formatting (en → "7:30 AM"), but the prefix is stable.
      expect(text, startsWith('Every day @ '));
      expect(text, contains('7:30'));
    });

    testWidgets('describes WeekdaySchedule with entry count', (tester) async {
      final (ctx, l10n) = await _pumpLocalised(tester);
      final text = scheduleDescription(
        ctx,
        l10n,
        const WeekdaySchedule(entries: [
          WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 7)),
          WeekdayEntry(weekday: 3, timeOfDay: Duration(hours: 8)),
        ]),
      );
      expect(text, 'Specific weekdays (2)');
    });

    testWidgets('describes MonthlyByWeekdaySchedule with entry count', (tester) async {
      final (ctx, l10n) = await _pumpLocalised(tester);
      final text = scheduleDescription(
        ctx,
        l10n,
        const MonthlyByWeekdaySchedule(entries: [
          MonthlyWeekdayEntry(occurrence: 1, weekday: 2, timeOfDay: Duration(hours: 7)),
        ]),
      );
      expect(text, 'Monthly by weekday (1)');
    });

    testWidgets('describes MonthlyByDateSchedule with entry count', (tester) async {
      final (ctx, l10n) = await _pumpLocalised(tester);
      final text = scheduleDescription(
        ctx,
        l10n,
        const MonthlyByDateSchedule(entries: [
          MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 7)),
          MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 7)),
          MonthlyDateEntry(dayOfMonth: 28, timeOfDay: Duration(hours: 7)),
        ]),
      );
      expect(text, 'Monthly by date (3)');
    });
  });

  group('reminderDescription', () {
    testWidgets('returns "No reminder" when offset is null', (tester) async {
      final (_, l10n) = await _pumpLocalised(tester);
      expect(reminderDescription(l10n, null), 'No reminder');
    });

    testWidgets('returns "When it starts" when offset is Duration.zero', (tester) async {
      final (_, l10n) = await _pumpLocalised(tester);
      expect(reminderDescription(l10n, Duration.zero), 'When it starts');
    });

    testWidgets('returns "N min before" when offset is positive', (tester) async {
      final (_, l10n) = await _pumpLocalised(tester);
      expect(reminderDescription(l10n, const Duration(minutes: 15)), '15 min before');
      expect(reminderDescription(l10n, const Duration(minutes: 60)), '60 min before');
    });
  });

  group('weekdayName', () {
    testWidgets('maps 1..7 to Mon..Sun (en)', (tester) async {
      final (_, l10n) = await _pumpLocalised(tester);
      expect(weekdayName(l10n, 1), 'Mon');
      expect(weekdayName(l10n, 2), 'Tue');
      expect(weekdayName(l10n, 3), 'Wed');
      expect(weekdayName(l10n, 4), 'Thu');
      expect(weekdayName(l10n, 5), 'Fri');
      expect(weekdayName(l10n, 6), 'Sat');
      expect(weekdayName(l10n, 7), 'Sun');
    });

    testWidgets('returns empty string for out-of-range weekday', (tester) async {
      final (_, l10n) = await _pumpLocalised(tester);
      expect(weekdayName(l10n, 0), '');
      expect(weekdayName(l10n, 8), '');
    });
  });

  group('occurrenceName', () {
    testWidgets('maps 1..4 to 1st..4th (en)', (tester) async {
      final (_, l10n) = await _pumpLocalised(tester);
      expect(occurrenceName(l10n, 1), '1st');
      expect(occurrenceName(l10n, 2), '2nd');
      expect(occurrenceName(l10n, 3), '3rd');
      expect(occurrenceName(l10n, 4), '4th');
    });

    testWidgets('returns empty string for out-of-range occurrence', (tester) async {
      final (_, l10n) = await _pumpLocalised(tester);
      expect(occurrenceName(l10n, 0), '');
      expect(occurrenceName(l10n, 5), '');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Pumps a trivial widget tree and sets the platform locale so that
/// [formatLocaleDate] (which uses [platformDispatcher.locale]) is deterministic.
Future<void> _pumpLocalised(
  WidgetTester tester, {
  Locale locale = const Locale('en', 'US'),
}) async {
  tester.binding.platformDispatcher.localeTestValue = locale;
  addTearDown(() => tester.binding.platformDispatcher.clearLocaleTestValue());

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
      home: const SizedBox(),
    ),
  );
}

void main() {
  group('formatLocaleDate', () {
    testWidgets('formats a date in en_US locale as M/d/yyyy', (tester) async {
      await _pumpLocalised(tester, locale: const Locale('en', 'US'));
      expect(formatLocaleDate(DateTime(2026, 3, 30)), '3/30/2026');
    });

    testWidgets('formats a date in en_GB locale as dd/MM/yyyy', (tester) async {
      await _pumpLocalised(tester, locale: const Locale('en', 'GB'));
      expect(formatLocaleDate(DateTime(2026, 3, 30)), '30/03/2026');
    });

    testWidgets('formats a date in fr locale as d/MM/yyyy', (tester) async {
      await _pumpLocalised(tester, locale: const Locale('fr'));
      expect(formatLocaleDate(DateTime(2026, 3, 30)), '30/03/2026');
    });

    testWidgets('formats a date in de locale as d.M.yyyy', (tester) async {
      await _pumpLocalised(tester, locale: const Locale('de'));
      final result = formatLocaleDate(DateTime(2026, 3, 30));
      // German DateFormat.yMd produces "30.3.2026" (single-digit month, no leading zero)
      expect(result, '30.3.2026');
    });
  });
}

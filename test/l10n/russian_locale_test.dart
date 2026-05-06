import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Pumps a trivial widget tree with the given locale so [AppLocalizations.of]
/// resolves during tests.
Future<AppLocalizations> _pumpLocalised(WidgetTester tester, Locale locale) async {
  late AppLocalizations l10n;
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
          l10n = AppLocalizations.of(context)!;
          return const SizedBox();
        },
      ),
    ),
  );
  return l10n;
}

void main() {
  group('Russian locale', () {
    testWidgets('AppLocalizations resolves for Locale("ru")', (tester) async {
      final l10n = await _pumpLocalised(tester, const Locale('ru'));
      expect(l10n, isNotNull);
    });

    testWidgets('dashboardTitle is a non-empty string in Russian', (tester) async {
      final l10n = await _pumpLocalised(tester, const Locale('ru'));
      expect(l10n.dashboardTitle, isNotEmpty);
    });

    testWidgets('languagePickerTitle is a non-empty string in all locales', (tester) async {
      for (final locale in [const Locale('en'), const Locale('fr'), const Locale('de'), const Locale('ru')]) {
        final l10n = await _pumpLocalised(tester, locale);
        expect(l10n.languagePickerTitle, isNotEmpty, reason: 'Failed for locale: $locale');
      }
    });

    testWidgets('languageEnglish is a non-empty string in all locales', (tester) async {
      for (final locale in [const Locale('en'), const Locale('fr'), const Locale('de'), const Locale('ru')]) {
        final l10n = await _pumpLocalised(tester, locale);
        expect(l10n.languageEnglish, isNotEmpty, reason: 'Failed for locale: $locale');
      }
    });

    testWidgets('languageFrench is a non-empty string in all locales', (tester) async {
      for (final locale in [const Locale('en'), const Locale('fr'), const Locale('de'), const Locale('ru')]) {
        final l10n = await _pumpLocalised(tester, locale);
        expect(l10n.languageFrench, isNotEmpty, reason: 'Failed for locale: $locale');
      }
    });

    testWidgets('languageGerman is a non-empty string in all locales', (tester) async {
      for (final locale in [const Locale('en'), const Locale('fr'), const Locale('de'), const Locale('ru')]) {
        final l10n = await _pumpLocalised(tester, locale);
        expect(l10n.languageGerman, isNotEmpty, reason: 'Failed for locale: $locale');
      }
    });

    testWidgets('languageRussian is a non-empty string in all locales', (tester) async {
      for (final locale in [const Locale('en'), const Locale('fr'), const Locale('de'), const Locale('ru')]) {
        final l10n = await _pumpLocalised(tester, locale);
        expect(l10n.languageRussian, isNotEmpty, reason: 'Failed for locale: $locale');
      }
    });

    testWidgets('languageSystem is a non-empty string in all locales', (tester) async {
      for (final locale in [const Locale('en'), const Locale('fr'), const Locale('de'), const Locale('ru')]) {
        final l10n = await _pumpLocalised(tester, locale);
        expect(l10n.languageSystem, isNotEmpty, reason: 'Failed for locale: $locale');
      }
    });
  });
}

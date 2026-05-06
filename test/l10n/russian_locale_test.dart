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

    // Russian has 4 CLDR plural categories: one (1, 21, 31…), few (2–4, 22–24…),
    // many (5–20, 25–30…), other (fractions / fallback). The tests below verify
    // that each category resolves to the grammatically correct form.

    testWidgets('pactsActive uses correct Russian plural forms', (tester) async {
      final l10n = await _pumpLocalised(tester, const Locale('ru'));

      // one: 1 активный пакт
      expect(l10n.pactsActive(1), contains('активный пакт'));
      // few (2–4): N активных пакта
      expect(l10n.pactsActive(2), contains('активных пакта'));
      expect(l10n.pactsActive(3), contains('активных пакта'));
      expect(l10n.pactsActive(4), contains('активных пакта'));
      // many (5–20): N активных пактов
      expect(l10n.pactsActive(5), contains('активных пактов'));
      expect(l10n.pactsActive(11), contains('активных пактов'));
      expect(l10n.pactsActive(20), contains('активных пактов'));
      // few again at 22–24
      expect(l10n.pactsActive(22), contains('активных пакта'));
      // many again at 25
      expect(l10n.pactsActive(25), contains('активных пактов'));
    });

    testWidgets('daysRemaining uses correct Russian plural forms', (tester) async {
      final l10n = await _pumpLocalised(tester, const Locale('ru'));

      // one
      expect(l10n.daysRemaining(1), contains('Остался 1 день'));
      // few (2–4): Осталось N дня
      expect(l10n.daysRemaining(2), contains('дня'));
      expect(l10n.daysRemaining(4), contains('дня'));
      // many (5–20): Осталось N дней
      expect(l10n.daysRemaining(5), contains('дней'));
      expect(l10n.daysRemaining(11), contains('дней'));
      // few again at 22–24
      expect(l10n.daysRemaining(22), contains('дня'));
      // many again at 25
      expect(l10n.daysRemaining(25), contains('дней'));
    });
  });
}

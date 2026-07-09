import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/android/language_picker_dialog_android.dart';

void main() {
  testWidgets('option labels do not overflow on a narrow screen with Russian translations', (tester) async {
    // Matches CI's narrow 320dp Android AVD, which is where this was first caught.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext capturedContext;
    late AppLocalizations ruL10n;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
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
            ruL10n = AppLocalizations.of(context)!;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final options = <({String label, Locale? locale})>[
      (label: ruL10n.languageEnglish, locale: const Locale('en')),
      (label: ruL10n.languageFrench, locale: const Locale('fr')),
      (label: ruL10n.languageGerman, locale: const Locale('de')),
      (label: ruL10n.languageRussian, locale: const Locale('ru')),
      (label: ruL10n.languageSystem, locale: null),
    ];

    // currentOverride: ru so the selected-item checkmark renders too (widest row).
    unawaited(showMaterialLanguagePicker(capturedContext, options, const Locale('ru'), ruL10n));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

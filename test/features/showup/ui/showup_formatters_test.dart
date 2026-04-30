import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Pumps a trivial widget tree so that [AppLocalizations.of] and
/// [Localizations.localeOf] resolve during tests.
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
  group('formatShowupDate', () {
    testWidgets('formats a date using the current locale (en)', (tester) async {
      final (ctx, _) = await _pumpLocalised(tester);
      final text = formatShowupDate(ctx, DateTime(2026, 3, 30, 7, 30));
      expect(text, '3/30/2026');
    });

    testWidgets('formats a date using the current locale (fr)', (tester) async {
      final (ctx, _) = await _pumpLocalised(tester, locale: const Locale('fr'));
      final text = formatShowupDate(ctx, DateTime(2026, 3, 30, 7, 30));
      expect(text, '30/03/2026');
    });
  });

  group('formatShowupTime', () {
    testWidgets('formats a time using the current locale (en → h:mm am/pm)', (tester) async {
      final (ctx, _) = await _pumpLocalised(tester);
      final text = formatShowupTime(ctx, DateTime(2026, 3, 30, 7, 30));
      // DateFormat.jm('en') → "7:30 AM"
      expect(text, contains('7:30'));
      expect(text.toLowerCase(), contains('am'));
    });
  });

  group('showupStatusText', () {
    testWidgets('maps enum values to localized labels (en)', (tester) async {
      final (_, l10n) = await _pumpLocalised(tester);
      expect(showupStatusText(l10n, ShowupStatus.pending), l10n.showupPending);
      expect(showupStatusText(l10n, ShowupStatus.done), l10n.showupDone);
      expect(showupStatusText(l10n, ShowupStatus.failed), l10n.showupFailed);
    });
  });
}

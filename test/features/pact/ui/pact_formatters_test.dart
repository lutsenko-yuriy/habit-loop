import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

Future<AppLocalizations> _pumpAndGetL10n(WidgetTester tester) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
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
  group('pactStatusText', () {
    testWidgets('maps PactStatus values to localized labels (en)', (tester) async {
      final l10n = await _pumpAndGetL10n(tester);
      expect(pactStatusText(l10n, PactStatus.active), l10n.pactStatusActive);
      expect(pactStatusText(l10n, PactStatus.stopped), l10n.pactStatusStopped);
      expect(pactStatusText(l10n, PactStatus.completed), l10n.pactStatusCompleted);
    });
  });
}

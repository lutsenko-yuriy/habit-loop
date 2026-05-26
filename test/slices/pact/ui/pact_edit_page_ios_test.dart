import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_edit_page_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

Widget _buildApp(PactCreationState state) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: PactEditPageIos(
      state: state,
      onHabitNameChanged: (_) {},
      onReminderOffsetChanged: (_) {},
      onClearReminder: () {},
      onPageChanged: (_) {},
      onJumpToStep: (_) {},
      onClose: () {},
      onSubmit: () {},
      isSaving: false,
    ),
  );
}

void main() {
  testWidgets('iOS pact edit nav bar has explicit surface backgroundColor to prevent white-on-scroll', (tester) async {
    final state = PactCreationState(today: DateTime(2026, 3, 30));
    await tester.pumpWidget(_buildApp(state));

    final navBar = tester.widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar));
    final theme = Theme.of(tester.element(find.byType(PactEditPageIos)));

    expect(navBar.backgroundColor, theme.colorScheme.surface);
  });

  testWidgets('iOS pact edit scaffold has surface backgroundColor', (tester) async {
    final state = PactCreationState(today: DateTime(2026, 3, 30));
    await tester.pumpWidget(_buildApp(state));

    final scaffold = tester.widget<CupertinoPageScaffold>(find.byType(CupertinoPageScaffold));
    final theme = Theme.of(tester.element(find.byType(PactEditPageIos)));

    expect(scaffold.backgroundColor, theme.colorScheme.surface);
  });
}

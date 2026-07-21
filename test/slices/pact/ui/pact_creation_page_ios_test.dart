import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp, Theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_creation_page_ios.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

void main() {
  testWidgets('iOS pact creation shows a themed step indicator', (tester) async {
    final state = PactCreationState(
      today: DateTime(2026, 3, 30),
      currentStep: PactWizardStep.schedule,
    );

    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PactCreationPageIos(
          state: state,
          onHabitNameChanged: (_) {},
          onStartDateChanged: (_) {},
          onEndDateChanged: (_) {},
          onShowupDurationChanged: (_) {},
          onScheduleTypeChanged: (_) {},
          onScheduleChanged: (_) {},
          onReminderOffsetChanged: (_) {},
          onClearReminder: () {},
          onPageChanged: (_) {},
          onJumpToStep: (_) {},
          onClose: () {},
          onSubmit: () {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('pact-creation-step-indicator-ios')),
      findsOneWidget,
    );

    // The schedule step is index 3 (PactWizardStep.schedule.value == 3).
    // Segment 2 (showupDuration) is a *past* step → faded primary (alpha 0.3).
    // Segment 3 (schedule) is the *current* step → full primary.
    final pastSegment = tester.widget<Container>(
      find.byKey(const Key('pact-creation-step-indicator-ios-segment-2')),
    );
    final pastDecoration = pastSegment.decoration! as BoxDecoration;
    expect(pastDecoration.color, HabitLoopColors.primary.withValues(alpha: 0.3));

    final currentSegment = tester.widget<Container>(
      find.byKey(const Key('pact-creation-step-indicator-ios-segment-3')),
    );
    final currentDecoration = currentSegment.decoration! as BoxDecoration;
    expect(currentDecoration.color, HabitLoopColors.primary);
  });

  testWidgets('iOS pact creation nav bar has explicit surface backgroundColor to prevent white-on-scroll',
      (tester) async {
    final state = PactCreationState(today: DateTime(2026, 3, 30));

    await tester.pumpWidget(
      MaterialApp(
        theme: HabitLoopTheme.materialTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PactCreationPageIos(
          state: state,
          onHabitNameChanged: (_) {},
          onStartDateChanged: (_) {},
          onEndDateChanged: (_) {},
          onShowupDurationChanged: (_) {},
          onScheduleTypeChanged: (_) {},
          onScheduleChanged: (_) {},
          onReminderOffsetChanged: (_) {},
          onClearReminder: () {},
          onPageChanged: (_) {},
          onJumpToStep: (_) {},
          onClose: () {},
          onSubmit: () {},
        ),
      ),
    );

    final navBar = tester.widget<CupertinoNavigationBar>(find.byType(CupertinoNavigationBar));
    final theme = Theme.of(tester.element(find.byType(PactCreationPageIos)));

    expect(navBar.backgroundColor, theme.colorScheme.surface);
  });
}

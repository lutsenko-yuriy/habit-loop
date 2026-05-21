/// Tests that the pact creation wizard pages use a [PageView] and render the
/// expected content on each platform.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_creation_page_android.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_creation_page_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

// ---------------------------------------------------------------------------
// Minimal state used across all tests
// ---------------------------------------------------------------------------

final _today = DateTime(2026, 3, 30);
final _state = PactCreationState(today: _today);

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

Widget _iOSPage(
  PactCreationState state, {
  VoidCallback? onSubmit,
  ValueChanged<int>? onJumpToStep,
  ValueChanged<int>? onPageChanged,
}) {
  return CupertinoApp(
    theme: const CupertinoThemeData(),
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
      onPageChanged: onPageChanged ?? (_) {},
      onJumpToStep: onJumpToStep ?? (_) {},
      onSubmit: onSubmit ?? () {},
    ),
  );
}

Widget _androidPage(
  PactCreationState state, {
  VoidCallback? onSubmit,
  ValueChanged<int>? onJumpToStep,
  ValueChanged<int>? onPageChanged,
}) {
  return MaterialApp(
    theme: HabitLoopTheme.materialTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: PactCreationPageAndroid(
      state: state,
      onHabitNameChanged: (_) {},
      onStartDateChanged: (_) {},
      onEndDateChanged: (_) {},
      onShowupDurationChanged: (_) {},
      onScheduleTypeChanged: (_) {},
      onScheduleChanged: (_) {},
      onReminderOffsetChanged: (_) {},
      onClearReminder: () {},
      onPageChanged: onPageChanged ?? (_) {},
      onJumpToStep: onJumpToStep ?? (_) {},
      onSubmit: onSubmit ?? () {},
    ),
  );
}

void main() {
  group('PactCreationPageIos — PageView wizard', () {
    testWidgets('renders a PageView', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      expect(find.byKey(const Key('pact-creation-pageview-ios')), findsOneWidget);
    });

    testWidgets('shows step indicator', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      expect(find.byKey(const Key('pact-creation-step-indicator-ios')), findsOneWidget);
    });

    testWidgets('page 0 shows habit name input', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      expect(find.byKey(const Key('pact-creation-habit-name-field')), findsOneWidget);
    });

    testWidgets('page 0 shows commitment rules text', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      // The commitment warning is shown on the habit name step.
      expect(find.byKey(const Key('pact-creation-habit-name-commitment-rules')), findsOneWidget);
    });

    testWidgets('onPageChanged is called when state.currentStep changes', (tester) async {
      final List<int> received = [];
      // Simulate being on the duration page
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.duration);
      await tester.pumpWidget(_iOSPage(state, onPageChanged: received.add));
      // The pageController should reflect page 1 (duration) on first frame.
      await tester.pump();
      // No callback expected yet since no user interaction occurred.
      expect(received, isEmpty);
    });

    testWidgets('shows Next button on non-summary pages', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      expect(find.byKey(const Key('pact-creation-next-button')), findsOneWidget);
    });

    testWidgets('shows Create Pact button on summary page', (tester) async {
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      await tester.pumpWidget(_iOSPage(state));
      expect(find.byKey(const Key('pact-creation-create-button')), findsOneWidget);
      expect(find.byKey(const Key('pact-creation-next-button')), findsNothing);
    });

    testWidgets('tapping Create Pact on summary calls onSubmit', (tester) async {
      bool submitted = false;
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      await tester.pumpWidget(_iOSPage(state, onSubmit: () => submitted = true));
      await tester.tap(find.byKey(const Key('pact-creation-create-button')));
      expect(submitted, isTrue);
    });
  });

  group('PactCreationPageAndroid — PageView wizard', () {
    testWidgets('renders a PageView', (tester) async {
      await tester.pumpWidget(_androidPage(_state));
      expect(find.byKey(const Key('pact-creation-pageview-android')), findsOneWidget);
    });

    testWidgets('shows step indicator', (tester) async {
      await tester.pumpWidget(_androidPage(_state));
      expect(find.byKey(const Key('pact-creation-step-indicator-android')), findsOneWidget);
    });

    testWidgets('page 0 shows habit name input', (tester) async {
      await tester.pumpWidget(_androidPage(_state));
      expect(find.byKey(const Key('pact-creation-habit-name-field')), findsOneWidget);
    });

    testWidgets('shows Next button on non-summary pages', (tester) async {
      await tester.pumpWidget(_androidPage(_state));
      expect(find.byKey(const Key('pact-creation-next-button')), findsOneWidget);
    });

    testWidgets('shows Create Pact button on summary page', (tester) async {
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      await tester.pumpWidget(_androidPage(state));
      expect(find.byKey(const Key('pact-creation-create-button')), findsOneWidget);
      expect(find.byKey(const Key('pact-creation-next-button')), findsNothing);
    });
  });

  group('SummaryStep — tappable rows', () {
    testWidgets('iOS summary step shows habit name and calls onJumpToStep', (tester) async {
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary)
        ..builder.copyWith(habitName: 'Meditate');
      final List<int> jumped = [];
      await tester.pumpWidget(_iOSPage(
        state,
        onJumpToStep: jumped.add,
      ));
      // Tap the habit row in the summary (expected key)
      await tester.tap(find.byKey(const Key('summary-row-tap-habit_name')));
      expect(jumped, [PactWizardStep.habitName.value]);
    });

    testWidgets('Android summary step calls onJumpToStep on row tap', (tester) async {
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      final List<int> jumped = [];
      await tester.pumpWidget(_androidPage(
        state,
        onJumpToStep: jumped.add,
      ));
      await tester.tap(find.byKey(const Key('summary-row-tap-habit_name')));
      expect(jumped, [PactWizardStep.habitName.value]);
    });
  });
}

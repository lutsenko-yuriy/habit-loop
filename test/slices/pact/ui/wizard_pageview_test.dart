/// Tests that the pact creation wizard pages use a [PageView] and render the
/// expected content on each platform.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_creation_page_android.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_creation_page_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

// ---------------------------------------------------------------------------
// Minimal state used across all tests
// ---------------------------------------------------------------------------

final _today = DateTime(2026, 3, 30);
final _state = PactCreationState(today: _today);

/// A fully-complete state on the summary page: every required field filled in.
PactCreationState _completeSummaryState() => PactCreationState(
      today: _today,
      currentStep: PactWizardStep.summary,
      builder: PactBuilder(
        today: _today,
        habitName: 'Meditate',
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
      ),
    );

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

Widget _iOSPage(
  PactCreationState state, {
  VoidCallback? onSubmit,
  VoidCallback? onClose,
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
      onClose: onClose ?? () {},
      onSubmit: onSubmit ?? () {},
    ),
  );
}

Widget _androidPage(
  PactCreationState state, {
  VoidCallback? onSubmit,
  VoidCallback? onClose,
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
      onClose: onClose ?? () {},
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
      expect(find.byKey(const Key('pact-creation-habit-name-commitment-rules')), findsOneWidget);
    });

    testWidgets('shows close button on every page', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      expect(find.byKey(const Key('pact-creation-close-button')), findsOneWidget);
    });

    testWidgets('tapping close button calls onClose', (tester) async {
      bool closed = false;
      await tester.pumpWidget(_iOSPage(_state, onClose: () => closed = true));
      await tester.tap(find.byKey(const Key('pact-creation-close-button')));
      expect(closed, isTrue);
    });

    testWidgets('nav bar shows habit name when state has one', (tester) async {
      final state = PactCreationState(
        today: _today,
        builder: PactCreationState(today: _today).builder.copyWith(habitName: 'Meditate'),
      );
      await tester.pumpWidget(_iOSPage(state));
      expect(find.text('Meditate'), findsWidgets); // title + field value
    });

    testWidgets('does not show Next or Back button on non-summary pages', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      expect(find.byKey(const Key('pact-creation-next-button')), findsNothing);
    });

    testWidgets('shows Create Pact button only on summary page', (tester) async {
      final summaryState = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      await tester.pumpWidget(_iOSPage(summaryState));
      expect(find.byKey(const Key('pact-creation-create-button')), findsOneWidget);
    });

    testWidgets('does not show Create Pact button on non-summary pages', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      expect(find.byKey(const Key('pact-creation-create-button')), findsNothing);
    });

    testWidgets('Create Pact button is disabled when pact is incomplete', (tester) async {
      // Default state: empty habit name, no schedule → isComplete == false.
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      bool submitted = false;
      await tester.pumpWidget(_iOSPage(state, onSubmit: () => submitted = true));
      await tester.tap(find.byKey(const Key('pact-creation-create-button')));
      expect(submitted, isFalse);
    });

    testWidgets('tapping Create Pact on summary calls onSubmit when complete', (tester) async {
      bool submitted = false;
      await tester.pumpWidget(_iOSPage(_completeSummaryState(), onSubmit: () => submitted = true));
      await tester.tap(find.byKey(const Key('pact-creation-create-button')));
      expect(submitted, isTrue);
    });

    testWidgets('shows swipe hint on non-summary pages', (tester) async {
      await tester.pumpWidget(_iOSPage(_state));
      expect(find.text('Swipe to move between steps'), findsOneWidget);
    });

    testWidgets('shows swipe hint on summary page too', (tester) async {
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      await tester.pumpWidget(_iOSPage(state));
      expect(find.text('Swipe to move between steps'), findsOneWidget);
    });

    testWidgets('onPageChanged is called when state.currentStep changes', (tester) async {
      final List<int> received = [];
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.duration);
      await tester.pumpWidget(_iOSPage(state, onPageChanged: received.add));
      await tester.pump();
      expect(received, isEmpty);
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

    testWidgets('shows close button on every page', (tester) async {
      await tester.pumpWidget(_androidPage(_state));
      expect(find.byKey(const Key('pact-creation-close-button')), findsOneWidget);
    });

    testWidgets('tapping close button calls onClose', (tester) async {
      bool closed = false;
      await tester.pumpWidget(_androidPage(_state, onClose: () => closed = true));
      await tester.tap(find.byKey(const Key('pact-creation-close-button')));
      expect(closed, isTrue);
    });

    testWidgets('does not show Next or Back button on non-summary pages', (tester) async {
      await tester.pumpWidget(_androidPage(_state));
      expect(find.byKey(const Key('pact-creation-next-button')), findsNothing);
    });

    testWidgets('shows Create Pact button only on summary page', (tester) async {
      final summaryState = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      await tester.pumpWidget(_androidPage(summaryState));
      expect(find.byKey(const Key('pact-creation-create-button')), findsOneWidget);
    });

    testWidgets('does not show Create Pact button on non-summary pages', (tester) async {
      await tester.pumpWidget(_androidPage(_state));
      expect(find.byKey(const Key('pact-creation-create-button')), findsNothing);
    });

    testWidgets('Create Pact button is disabled when pact is incomplete', (tester) async {
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      bool submitted = false;
      await tester.pumpWidget(_androidPage(state, onSubmit: () => submitted = true));
      await tester.tap(find.byKey(const Key('pact-creation-create-button')));
      expect(submitted, isFalse);
    });

    testWidgets('tapping Create Pact on summary calls onSubmit when complete', (tester) async {
      bool submitted = false;
      await tester.pumpWidget(_androidPage(_completeSummaryState(), onSubmit: () => submitted = true));
      await tester.tap(find.byKey(const Key('pact-creation-create-button')));
      expect(submitted, isTrue);
    });

    testWidgets('shows swipe hint on non-summary pages', (tester) async {
      await tester.pumpWidget(_androidPage(_state));
      expect(find.text('Swipe to move between steps'), findsOneWidget);
    });

    testWidgets('shows swipe hint on summary page too', (tester) async {
      final state = PactCreationState(today: _today, currentStep: PactWizardStep.summary);
      await tester.pumpWidget(_androidPage(state));
      expect(find.text('Swipe to move between steps'), findsOneWidget);
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

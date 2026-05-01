import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_creation_page_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

void main() {
  testWidgets('iOS pact creation shows a themed step indicator', (tester) async {
    final state = PactCreationState(
      today: DateTime(2026, 3, 30),
      currentStep: PactCreationStep.schedule,
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
          onCommitmentChanged: (_) {},
          onNext: () {},
          onBack: () {},
          onSubmit: () {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('pact-creation-step-indicator-ios')),
      findsOneWidget,
    );

    final activeSegment = tester.widget<Container>(
      find.byKey(const Key('pact-creation-step-indicator-ios-segment-2')),
    );
    final activeDecoration = activeSegment.decoration! as BoxDecoration;
    expect(activeDecoration.color, HabitLoopColors.primary);
  });
}

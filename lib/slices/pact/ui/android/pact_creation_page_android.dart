import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/habit_name_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_duration_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/reminder_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/schedule_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/showup_duration_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/summary_step_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_page_scaffold.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_step_indicator.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_style.dart';

// Android pact creation wizard: 6-page PageView (habit name → duration → showup duration → schedule → reminder → summary).
class PactCreationPageAndroid extends StatelessWidget {
  const PactCreationPageAndroid({
    super.key,
    required this.state,
    required this.onHabitNameChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onShowupDurationChanged,
    required this.onScheduleTypeChanged,
    required this.onScheduleChanged,
    required this.onReminderOffsetChanged,
    required this.onClearReminder,
    required this.onPageChanged,
    required this.onJumpToStep,
    required this.onClose,
    required this.onSubmit,
  });

  final PactCreationState state;
  final ValueChanged<String> onHabitNameChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<Duration> onShowupDurationChanged;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;
  final ValueChanged<Duration> onReminderOffsetChanged;
  final VoidCallback onClearReminder;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onJumpToStep;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = WizardStyle.material(context);
    final step = state.currentStep;
    final habitName = state.habitName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          habitName.isNotEmpty ? habitName : (step.isLast ? l10n.wizardSummaryTitle : l10n.pactCreationTitle),
        ),
        leading: IconButton(
          key: const Key('pact-creation-close-button'),
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          WizardStepIndicator(
            style: style,
            currentIndex: step.value,
            stepCount: PactWizardStep.count,
            onStepTapped: onJumpToStep,
            keyPrefix: 'pact-creation-step-indicator-android',
          ),
          Expanded(
            child: WizardPageScaffold(
              currentPage: step.value,
              pageCount: PactWizardStep.count,
              pageViewKey: const Key('pact-creation-pageview-android'),
              onPageChanged: onPageChanged,
              hintText: l10n.wizardSwipeHint,
              hintTextColor: style.hintTextColor,
              pageBuilder: (index, focusNode) => _buildPage(index, focusNode, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, FocusNode focusNode, AppLocalizations l10n) {
    switch (PactWizardStep.values[index]) {
      case PactWizardStep.habitName:
        return HabitNameStepAndroid(
          state: state,
          l10n: l10n,
          onHabitNameChanged: onHabitNameChanged,
          focusNode: focusNode,
        );
      case PactWizardStep.duration:
        return PactDurationStepAndroid(
          state: state,
          l10n: l10n,
          onStartDateChanged: onStartDateChanged,
          onEndDateChanged: onEndDateChanged,
        );
      case PactWizardStep.showupDuration:
        return ShowupDurationStepAndroid(state: state, l10n: l10n, onChanged: onShowupDurationChanged);
      case PactWizardStep.schedule:
        return ScheduleStepAndroid(
          state: state,
          l10n: l10n,
          onScheduleTypeChanged: onScheduleTypeChanged,
          onScheduleChanged: onScheduleChanged,
        );
      case PactWizardStep.reminder:
        return ReminderStepAndroid(
          state: state,
          l10n: l10n,
          onReminderOffsetChanged: onReminderOffsetChanged,
          onClearReminder: onClearReminder,
        );
      case PactWizardStep.summary:
        return SummaryStepAndroid(
          state: state,
          l10n: l10n,
          onJumpToStep: onJumpToStep,
          onSubmit: onSubmit,
          isComplete: state.builder.isComplete,
        );
    }
  }
}

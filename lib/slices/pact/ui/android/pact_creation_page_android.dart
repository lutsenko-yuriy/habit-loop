import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/commitment_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_duration_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/reminder_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/schedule_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/showup_duration_step_android.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class PactCreationPageAndroid extends StatelessWidget {
  final PactCreationState state;
  final ValueChanged<String> onHabitNameChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<Duration> onShowupDurationChanged;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;
  final ValueChanged<Duration> onReminderOffsetChanged;
  final VoidCallback onClearReminder;
  final ValueChanged<bool> onCommitmentChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

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
    required this.onCommitmentChanged,
    required this.onNext,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pactCreationTitle),
        leading: !state.currentStep.isFirst
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              )
            : null,
      ),
      body: Column(
        children: [
          _HabitNameField(
            habitName: state.habitName,
            onChanged: onHabitNameChanged,
            l10n: l10n,
          ),
          _StepIndicator(currentStep: state.currentStep),
          Expanded(
            child: _buildStep(context, l10n),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        state: state,
        l10n: l10n,
        onNext: onNext,
        onSubmit: onSubmit,
      ),
    );
  }

  Widget _buildStep(BuildContext context, AppLocalizations l10n) {
    switch (state.currentStep) {
      case PactCreationStep.pactDuration:
        return PactDurationStepAndroid(
          state: state,
          l10n: l10n,
          onStartDateChanged: onStartDateChanged,
          onEndDateChanged: onEndDateChanged,
        );
      case PactCreationStep.showupDuration:
        return ShowupDurationStepAndroid(
          state: state,
          l10n: l10n,
          onChanged: onShowupDurationChanged,
        );
      case PactCreationStep.schedule:
        return ScheduleStepAndroid(
          state: state,
          l10n: l10n,
          onScheduleTypeChanged: onScheduleTypeChanged,
          onScheduleChanged: onScheduleChanged,
        );
      case PactCreationStep.reminder:
        return ReminderStepAndroid(
          state: state,
          l10n: l10n,
          onReminderOffsetChanged: onReminderOffsetChanged,
          onClearReminder: onClearReminder,
        );
      case PactCreationStep.commitment:
        return CommitmentStepAndroid(
          state: state,
          l10n: l10n,
          onCommitmentChanged: onCommitmentChanged,
        );
    }
  }
}

class _HabitNameField extends StatelessWidget {
  final String habitName;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  const _HabitNameField({
    required this.habitName,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: TextEditingController(text: habitName)
          ..selection = TextSelection.collapsed(offset: habitName.length),
        decoration: InputDecoration(
          labelText: l10n.habitNameLabel,
          hintText: l10n.habitNameHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final PactCreationStep currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(PactCreationStep.count, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color:
                    index <= currentStep.index ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.state,
    required this.l10n,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = state.currentStep.isLast;
    final canAdvance = state.canAdvanceFromStep;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canAdvance ? (isLastStep ? onSubmit : onNext) : null,
            child: Text(
              isLastStep ? l10n.createPactConfirm : l10n.next,
            ),
          ),
        ),
      ),
    );
  }
}

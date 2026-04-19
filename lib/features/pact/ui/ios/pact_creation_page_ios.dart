import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/pact/ui/ios/commitment_step_ios.dart';
import 'package:habit_loop/features/pact/ui/ios/pact_duration_step_ios.dart';
import 'package:habit_loop/features/pact/ui/ios/reminder_step_ios.dart';
import 'package:habit_loop/features/pact/ui/ios/schedule_step_ios.dart';
import 'package:habit_loop/features/pact/ui/ios/showup_duration_step_ios.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

class PactCreationPageIos extends StatelessWidget {
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

  const PactCreationPageIos({
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

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.pactCreationTitle),
        leading: !state.currentStep.isFirst
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onBack,
                child: Text(l10n.back),
              )
            : null,
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
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
              _BottomBar(
                state: state,
                l10n: l10n,
                onNext: onNext,
                onSubmit: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, AppLocalizations l10n) {
    switch (state.currentStep) {
      case PactCreationStep.pactDuration:
        return PactDurationStepIos(
          state: state,
          l10n: l10n,
          onStartDateChanged: onStartDateChanged,
          onEndDateChanged: onEndDateChanged,
          onShowupDurationChanged: onShowupDurationChanged,
        );
      case PactCreationStep.showupDuration:
        return ShowupDurationStepIos(
          state: state,
          l10n: l10n,
          onChanged: onShowupDurationChanged,
        );
      case PactCreationStep.schedule:
        return ScheduleStepIos(
          state: state,
          l10n: l10n,
          onScheduleTypeChanged: onScheduleTypeChanged,
          onScheduleChanged: onScheduleChanged,
        );
      case PactCreationStep.reminder:
        return ReminderStepIos(
          state: state,
          l10n: l10n,
          onReminderOffsetChanged: onReminderOffsetChanged,
          onClearReminder: onClearReminder,
        );
      case PactCreationStep.commitment:
        return CommitmentStepIos(
          state: state,
          l10n: l10n,
          onCommitmentChanged: onCommitmentChanged,
        );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final PactCreationStep currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('pact-creation-step-indicator-ios'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(PactCreationStep.count, (index) {
          return Expanded(
            child: Container(
              key: Key('pact-creation-step-indicator-ios-segment-$index'),
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: index <= currentStep.index
                    ? HabitLoopColors.primary
                    : CupertinoColors.tertiarySystemFill.resolveFrom(context),
              ),
            ),
          );
        }),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: CupertinoTextField(
        placeholder: l10n.habitNameHint,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            l10n.habitNameLabel,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 14,
            ),
          ),
        ),
        controller: TextEditingController(text: habitName)
          ..selection = TextSelection.collapsed(offset: habitName.length),
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: canAdvance
              ? (isLastStep ? onSubmit : onNext)
              : null,
          child: Text(
            isLastStep ? l10n.createPactConfirm : l10n.next,
          ),
        ),
      ),
    );
  }
}

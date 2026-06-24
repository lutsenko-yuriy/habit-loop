import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/tappable_summary_row.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_style.dart';

class SummaryStepIos extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<int> onJumpToStep;
  final VoidCallback onSubmit;
  final bool isComplete;

  const SummaryStepIos({
    super.key,
    required this.state,
    required this.l10n,
    required this.onJumpToStep,
    required this.onSubmit,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final style = WizardStyle.cupertino(context);
    final reminderText = reminderDescription(l10n, state.reminderOffset);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 16),
              Text(l10n.wizardSummaryTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: style.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TappableSummaryRow(
                      tapKey: 'summary-row-tap-${PactWizardStep.habitName.analyticsName}',
                      label: l10n.summaryHabit,
                      value: state.habitName.isEmpty ? '—' : state.habitName,
                      labelColor: style.labelColor,
                      onTap: () => onJumpToStep(PactWizardStep.habitName.value),
                      divider: Divider(color: style.dividerColor, height: 1),
                    ),
                    TappableSummaryRow(
                      tapKey: 'summary-row-tap-${PactWizardStep.duration.analyticsName}',
                      label: l10n.summaryDuration,
                      value: '${formatPactDate(state.startDate)} → ${formatPactDate(state.endDate)}',
                      labelColor: style.labelColor,
                      onTap: () => onJumpToStep(PactWizardStep.duration.value),
                      divider: Divider(color: style.dividerColor, height: 1),
                    ),
                    TappableSummaryRow(
                      tapKey: 'summary-row-tap-${PactWizardStep.showupDuration.analyticsName}',
                      label: l10n.summaryShowupDuration,
                      value: l10n.showupDurationMinutes(state.showupDuration?.inMinutes ?? 0),
                      labelColor: style.labelColor,
                      onTap: () => onJumpToStep(PactWizardStep.showupDuration.value),
                      divider: Divider(color: style.dividerColor, height: 1),
                    ),
                    TappableSummaryRow(
                      tapKey: 'summary-row-tap-${PactWizardStep.schedule.analyticsName}',
                      label: l10n.summarySchedule,
                      value: scheduleDescription(context, l10n, state.schedule),
                      labelColor: style.labelColor,
                      onTap: () => onJumpToStep(PactWizardStep.schedule.value),
                      divider: Divider(color: style.dividerColor, height: 1),
                    ),
                    TappableSummaryRow(
                      tapKey: 'summary-row-tap-${PactWizardStep.reminder.analyticsName}',
                      label: l10n.summaryReminder,
                      value: reminderText,
                      labelColor: style.labelColor,
                      onTap: () => onJumpToStep(PactWizardStep.reminder.value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              key: const Key('pact-creation-create-button'),
              onPressed: isComplete ? onSubmit : null,
              child: Text(l10n.createPactConfirm),
            ),
          ),
        ),
      ],
    );
  }
}

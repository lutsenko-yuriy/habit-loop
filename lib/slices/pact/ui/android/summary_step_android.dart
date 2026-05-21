import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/summary_row.dart';

/// Summary wizard page on Android.
///
/// Displays all the collected pact data as tappable rows. Tapping a row
/// navigates back to that step so the user can revise before committing.
/// The "Create Pact" button lives in the parent page's bottom bar.
class SummaryStepAndroid extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;

  /// Called with the target page index when the user taps a summary row.
  final ValueChanged<int> onJumpToStep;

  const SummaryStepAndroid({
    super.key,
    required this.state,
    required this.l10n,
    required this.onJumpToStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminderText = reminderDescription(l10n, state.reminderOffset);
    final labelColor = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(l10n.wizardSummaryTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _TappableSummaryRow(
                stepName: PactWizardStep.habitName.analyticsName,
                label: l10n.summaryHabit,
                value: state.habitName.isEmpty ? '—' : state.habitName,
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.habitName.value),
              ),
              const Divider(height: 1),
              _TappableSummaryRow(
                stepName: PactWizardStep.duration.analyticsName,
                label: l10n.summaryDuration,
                value: '${formatPactDate(context, state.startDate)} → ${formatPactDate(context, state.endDate)}',
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.duration.value),
              ),
              const Divider(height: 1),
              _TappableSummaryRow(
                stepName: PactWizardStep.showupDuration.analyticsName,
                label: l10n.summaryShowupDuration,
                value: l10n.showupDurationMinutes(state.showupDuration?.inMinutes ?? 0),
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.showupDuration.value),
              ),
              const Divider(height: 1),
              _TappableSummaryRow(
                stepName: PactWizardStep.schedule.analyticsName,
                label: l10n.summarySchedule,
                value: scheduleDescription(context, l10n, state.schedule),
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.schedule.value),
              ),
              const Divider(height: 1),
              _TappableSummaryRow(
                stepName: PactWizardStep.reminder.analyticsName,
                label: l10n.summaryReminder,
                value: reminderText,
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.reminder.value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TappableSummaryRow extends StatelessWidget {
  final String stepName;
  final String label;
  final String value;
  final Color labelColor;
  final VoidCallback onTap;

  const _TappableSummaryRow({
    required this.stepName,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('summary-row-tap-$stepName'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: SummaryRow(label: label, value: value, labelColor: labelColor),
            ),
            Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

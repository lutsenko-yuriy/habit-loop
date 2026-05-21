import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/summary_row.dart';

/// Summary wizard page on iOS.
///
/// Displays all the collected pact data as tappable rows. Tapping a row
/// navigates back to that step so the user can revise their choice before
/// committing. The "Create Pact" button is hosted by the parent page's bottom
/// bar, not inside this widget.
class SummaryStepIos extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;

  /// Called with the target page index when the user taps a summary row to
  /// jump back to that step.
  final ValueChanged<int> onJumpToStep;

  const SummaryStepIos({
    super.key,
    required this.state,
    required this.l10n,
    required this.onJumpToStep,
  });

  @override
  Widget build(BuildContext context) {
    final reminderText = reminderDescription(l10n, state.reminderOffset);
    final labelColor = CupertinoColors.systemGrey.resolveFrom(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.wizardSummaryTitle,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
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
              _TappableSummaryRow(
                stepName: PactWizardStep.duration.analyticsName,
                label: l10n.summaryDuration,
                value: '${formatPactDate(context, state.startDate)} → ${formatPactDate(context, state.endDate)}',
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.duration.value),
              ),
              _TappableSummaryRow(
                stepName: PactWizardStep.showupDuration.analyticsName,
                label: l10n.summaryShowupDuration,
                value: l10n.showupDurationMinutes(state.showupDuration?.inMinutes ?? 0),
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.showupDuration.value),
              ),
              _TappableSummaryRow(
                stepName: PactWizardStep.schedule.analyticsName,
                label: l10n.summarySchedule,
                value: scheduleDescription(context, l10n, state.schedule),
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.schedule.value),
              ),
              _TappableSummaryRow(
                stepName: PactWizardStep.reminder.analyticsName,
                label: l10n.summaryReminder,
                value: reminderText,
                labelColor: labelColor,
                onTap: () => onJumpToStep(PactWizardStep.reminder.value),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// A [SummaryRow] wrapped in a [GestureDetector] so the user can tap it to
/// jump back to the corresponding wizard step.
class _TappableSummaryRow extends StatelessWidget {
  final String stepName;
  final String label;
  final String value;
  final Color labelColor;
  final VoidCallback onTap;
  final bool isLast;

  const _TappableSummaryRow({
    required this.stepName,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('summary-row-tap-$stepName'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          SummaryRow(label: label, value: value, labelColor: labelColor),
          if (!isLast) Divider(color: CupertinoColors.separator.resolveFrom(context), height: 1),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/features/pact/ui/generic/summary_row.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class CommitmentStepAndroid extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<bool> onCommitmentChanged;

  const CommitmentStepAndroid({
    super.key,
    required this.state,
    required this.l10n,
    required this.onCommitmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final reminderText = reminderDescription(l10n, state.reminderOffset);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(l10n.commitmentStep, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SummaryRow(
                label: l10n.summaryHabit,
                value: state.habitName,
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SummaryRow(
                label: l10n.summaryDuration,
                value: '${formatPactDate(context, state.startDate)} → ${formatPactDate(context, state.endDate)}',
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SummaryRow(
                label: l10n.summaryShowupDuration,
                value: l10n.showupDurationMinutes(state.showupDuration?.inMinutes ?? 0),
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SummaryRow(
                label: l10n.summarySchedule,
                value: scheduleDescription(context, l10n, state.schedule),
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SummaryRow(
                label: l10n.summaryReminder,
                value: reminderText,
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.commitmentWarning,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: state.commitmentAccepted,
          onChanged: (v) => onCommitmentChanged(v ?? false),
          title: Text(
            l10n.commitmentAccept,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

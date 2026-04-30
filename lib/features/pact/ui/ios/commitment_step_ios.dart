import 'package:flutter/cupertino.dart';
import 'package:habit_loop/features/pact/application/pact_creation_state.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/features/pact/ui/generic/summary_row.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class CommitmentStepIos extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<bool> onCommitmentChanged;

  const CommitmentStepIos({
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
        Text(
          l10n.commitmentStep,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SummaryRow(
                label: l10n.summaryHabit,
                value: state.habitName,
                labelColor: CupertinoColors.systemGrey,
              ),
              SummaryRow(
                label: l10n.summaryDuration,
                value: '${formatPactDate(context, state.startDate)} → ${formatPactDate(context, state.endDate)}',
                labelColor: CupertinoColors.systemGrey,
              ),
              SummaryRow(
                label: l10n.summaryShowupDuration,
                value: l10n.showupDurationMinutes(state.showupDuration?.inMinutes ?? 0),
                labelColor: CupertinoColors.systemGrey,
              ),
              SummaryRow(
                label: l10n.summarySchedule,
                value: scheduleDescription(context, l10n, state.schedule),
                labelColor: CupertinoColors.systemGrey,
              ),
              SummaryRow(
                label: l10n.summaryReminder,
                value: reminderText,
                labelColor: CupertinoColors.systemGrey,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemYellow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n.commitmentWarning,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => onCommitmentChanged(!state.commitmentAccepted),
          child: Row(
            children: [
              Icon(
                state.commitmentAccepted ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                color: state.commitmentAccepted ? CupertinoTheme.of(context).primaryColor : CupertinoColors.systemGrey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.commitmentAccept,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

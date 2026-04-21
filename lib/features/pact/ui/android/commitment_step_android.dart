import 'package:flutter/material.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

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

  String _formatDate(BuildContext context, DateTime d) =>
      DateFormat.yMd(Localizations.localeOf(context).toString()).format(d);

  String _scheduleDescription(BuildContext context) {
    final s = state.schedule;
    if (s == null) return '';
    if (s is DailySchedule) {
      final t = TimeOfDay(
              hour: s.timeOfDay.inHours, minute: s.timeOfDay.inMinutes % 60)
          .format(context);
      return '${l10n.scheduleDaily} @ $t';
    }
    if (s is WeekdaySchedule)
      return '${l10n.scheduleWeekday} (${s.entries.length})';
    if (s is MonthlyByWeekdaySchedule)
      return '${l10n.scheduleMonthlyByWeekday} (${s.entries.length})';
    if (s is MonthlyByDateSchedule)
      return '${l10n.scheduleMonthlyByDate} (${s.entries.length})';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final reminderText = state.reminderOffset == null
        ? l10n.reminderNone
        : state.reminderOffset == Duration.zero
            ? l10n.reminderAtStart
            : l10n.reminderMinutesBefore(state.reminderOffset!.inMinutes);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(l10n.commitmentStep,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _SummaryRow(label: l10n.summaryHabit, value: state.habitName),
              _SummaryRow(
                label: l10n.summaryDuration,
                value:
                    '${_formatDate(context, state.startDate)} → ${_formatDate(context, state.endDate)}',
              ),
              _SummaryRow(
                label: l10n.summaryShowupDuration,
                value: l10n.showupDurationMinutes(
                    state.showupDuration?.inMinutes ?? 0),
              ),
              _SummaryRow(
                  label: l10n.summarySchedule,
                  value: _scheduleDescription(context)),
              _SummaryRow(label: l10n.summaryReminder, value: reminderText),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

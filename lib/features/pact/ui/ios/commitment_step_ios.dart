import 'package:flutter/cupertino.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
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

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _scheduleDescription() {
    final s = state.schedule;
    if (s == null) return '';
    if (s is DailySchedule) {
      final h = s.timeOfDay.inHours.toString().padLeft(2, '0');
      final m = (s.timeOfDay.inMinutes % 60).toString().padLeft(2, '0');
      return '${l10n.scheduleDaily} @ $h:$m';
    }
    if (s is WeekdaySchedule) {
      return '${l10n.scheduleWeekday} (${s.entries.length})';
    }
    if (s is MonthlyByWeekdaySchedule) {
      return '${l10n.scheduleMonthlyByWeekday} (${s.entries.length})';
    }
    if (s is MonthlyByDateSchedule) {
      return '${l10n.scheduleMonthlyByDate} (${s.entries.length})';
    }
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
              _SummaryRow(label: l10n.summaryHabit, value: state.habitName),
              _SummaryRow(
                label: l10n.summaryDuration,
                value:
                    '${_formatDate(state.startDate)} → ${_formatDate(state.endDate)}',
              ),
              _SummaryRow(
                label: l10n.summaryShowupDuration,
                value: l10n.showupDurationMinutes(
                    state.showupDuration?.inMinutes ?? 0),
              ),
              _SummaryRow(
                  label: l10n.summarySchedule,
                  value: _scheduleDescription()),
              _SummaryRow(label: l10n.summaryReminder, value: reminderText),
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
                state.commitmentAccepted
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: state.commitmentAccepted
                    ? CupertinoTheme.of(context).primaryColor
                    : CupertinoColors.systemGrey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.commitmentAccept,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
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
              style: const TextStyle(
                color: CupertinoColors.systemGrey,
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

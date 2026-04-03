import 'package:flutter/material.dart';
import 'package:habit_loop/features/pact/domain/pact_creation_state.dart';
import 'package:intl/intl.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

class PactDurationStepAndroid extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;

  const PactDurationStepAndroid({
    super.key,
    required this.state,
    required this.l10n,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(l10n.pactDurationStep,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        _DateTile(
          label: l10n.startDateLabel,
          date: state.startDate,
          onTap: () async {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final picked = await showDatePicker(
              context: context,
              initialDate: state.startDate,
              firstDate: today,
              lastDate: DateTime(2040),
            );
            if (picked != null) onStartDateChanged(picked);
          },
        ),
        const SizedBox(height: 12),
        _DateTile(
          label: l10n.endDateLabel,
          date: state.endDate,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.endDate,
              firstDate: state.startDate.add(const Duration(days: 1)),
              lastDate: DateTime(2040),
            );
            if (picked != null) onEndDateChanged(picked);
          },
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      title: Text(label),
      trailing: Text(
        DateFormat.yMd(Localizations.localeOf(context).toString()).format(date),
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
      onTap: onTap,
    );
  }
}

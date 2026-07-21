import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';

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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tileColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      children: [
        const SizedBox(height: AppSpacing.s16),
        Text(l10n.pactDurationStep, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s24),
        DateRowTile(
          label: l10n.startDateLabel,
          value: formatLocaleDate(state.startDate),
          valueColor: primaryColor,
          backgroundColor: tileColor,
          cornerRadius: 12,
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
        const SizedBox(height: AppSpacing.s12),
        DateRowTile(
          label: l10n.endDateLabel,
          value: formatLocaleDate(state.endDate),
          valueColor: primaryColor,
          backgroundColor: tileColor,
          cornerRadius: 12,
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

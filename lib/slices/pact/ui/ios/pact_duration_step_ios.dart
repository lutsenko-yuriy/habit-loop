import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';

class PactDurationStepIos extends StatelessWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<Duration> onShowupDurationChanged;

  const PactDurationStepIos({
    super.key,
    required this.state,
    required this.l10n,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onShowupDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final fill = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.pactDurationStep,
          style: AppTypography.wizardStepTitle,
        ),
        const SizedBox(height: AppSpacing.xl),
        DateRowTile(
          label: l10n.startDateLabel,
          value: formatLocaleDate(state.startDate),
          valueColor: primaryColor,
          backgroundColor: fill,
          onTap: () => _showDatePicker(
            context,
            state.startDate,
            minimumDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
            onDateChanged: onStartDateChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DateRowTile(
          label: l10n.endDateLabel,
          value: formatLocaleDate(state.endDate),
          valueColor: primaryColor,
          backgroundColor: fill,
          onTap: () => _showDatePicker(
            context,
            state.endDate,
            minimumDate: state.startDate.add(const Duration(days: 1)),
            onDateChanged: onEndDateChanged,
          ),
        ),
      ],
    );
  }

  void _showDatePicker(
    BuildContext context,
    DateTime initialDate, {
    DateTime? minimumDate,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    unawaited(
      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => ColoredBox(
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: minimumDate,
                  onDateTimeChanged: onDateChanged,
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

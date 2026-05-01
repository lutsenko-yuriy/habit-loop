import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.pactDurationStep,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _DateRow(
          label: l10n.startDateLabel,
          date: state.startDate,
          onTap: () => _showDatePicker(
            context,
            state.startDate,
            minimumDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
            onDateChanged: onStartDateChanged,
          ),
        ),
        const SizedBox(height: 16),
        _DateRow(
          label: l10n.endDateLabel,
          date: state.endDate,
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

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              formatLocaleDate(context, date),
              style: TextStyle(
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

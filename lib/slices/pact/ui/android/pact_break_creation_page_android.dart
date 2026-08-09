import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_state.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/animated_reveal.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';

class PactBreakCreationPageAndroid extends StatefulWidget {
  final PactBreakCreationState state;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<bool> onUntilPactEndsChanged;
  final ValueChanged<String> onRationaleChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  const PactBreakCreationPageAndroid({
    super.key,
    required this.state,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onUntilPactEndsChanged,
    required this.onRationaleChanged,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  State<PactBreakCreationPageAndroid> createState() => _PactBreakCreationPageAndroidState();
}

class _PactBreakCreationPageAndroidState extends State<PactBreakCreationPageAndroid> {
  late final TextEditingController _rationaleController;

  @override
  void initState() {
    super.initState();
    _rationaleController = TextEditingController(text: widget.state.rationale)
      ..selection = TextSelection.collapsed(offset: widget.state.rationale.length);
  }

  @override
  void didUpdateWidget(covariant PactBreakCreationPageAndroid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.rationale != _rationaleController.text) {
      _rationaleController.value = TextEditingValue(
        text: widget.state.rationale,
        selection: TextSelection.collapsed(offset: widget.state.rationale.length),
      );
    }
  }

  @override
  void dispose() {
    _rationaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final tileColor = theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(l10n.startBreakTitle),
        leading: IconButton(
          key: const Key('break-close-button'),
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
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
              if (picked != null) widget.onStartDateChanged(picked);
            },
          ),
          AnimatedReveal(
            visible: !state.untilPactEnds,
            child: Column(
              key: const Key('break-end-date-row'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    if (picked != null) widget.onEndDateChanged(picked);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(child: Text(l10n.breakUntilPactEnds)),
              Switch(
                key: const Key('break-until-pact-ends-switch'),
                value: state.untilPactEnds,
                onChanged: widget.onUntilPactEndsChanged,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          TextField(
            key: const Key('break-rationale-field'),
            controller: _rationaleController,
            decoration: InputDecoration(hintText: l10n.breakRationaleHint),
            maxLines: null,
            minLines: 3,
            onChanged: widget.onRationaleChanged,
          ),
          if (state.nextShowupAfterEnd != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              l10n.breakNextShowupHint(formatLocaleDate(state.nextShowupAfterEnd!)),
              key: const Key('break-next-showup-hint'),
              style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.s24),
          if (state.submitError != null) ...[
            Text(
              l10n.startBreakError,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          FilledButton(
            key: const Key('break-submit-button'),
            onPressed: state.canSubmit ? widget.onSubmit : null,
            child: state.isSubmitting
                ? SizedBox(
                    height: AppSpacing.s20,
                    width: AppSpacing.s20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                  )
                : Text(l10n.startBreakConfirm),
          ),
        ],
      ),
    );
  }
}

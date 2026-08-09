import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_state.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/animated_reveal.dart';
import 'package:habit_loop/theme/widgets/date_row_tile.dart';

class PactBreakCreationPageIos extends StatefulWidget {
  final PactBreakCreationState state;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<bool> onUntilPactEndsChanged;
  final ValueChanged<String> onRationaleChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  const PactBreakCreationPageIos({
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
  State<PactBreakCreationPageIos> createState() => _PactBreakCreationPageIosState();
}

class _PactBreakCreationPageIosState extends State<PactBreakCreationPageIos> {
  late final TextEditingController _rationaleController;

  // Last non-null value, so the collapsing AnimatedReveal keeps fading out the
  // actual hint text instead of a now-null value (HAB-215) — matching
  // ShowupDetailContent's _lastOnStartBreak pattern for the same reason.
  DateTime? _lastNextShowupAfterEnd;

  @override
  void initState() {
    super.initState();
    _rationaleController = TextEditingController(text: widget.state.rationale)
      ..selection = TextSelection.collapsed(offset: widget.state.rationale.length);
    _lastNextShowupAfterEnd = widget.state.nextShowupAfterEnd;
  }

  @override
  void didUpdateWidget(covariant PactBreakCreationPageIos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.rationale != _rationaleController.text) {
      _rationaleController.value = TextEditingValue(
        text: widget.state.rationale,
        selection: TextSelection.collapsed(offset: widget.state.rationale.length),
      );
    }
    if (widget.state.nextShowupAfterEnd != null) _lastNextShowupAfterEnd = widget.state.nextShowupAfterEnd;
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
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final fill = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        middle: Text(l10n.startBreakTitle),
        leading: CupertinoButton(
          key: const Key('break-close-button'),
          padding: EdgeInsets.zero,
          onPressed: widget.onClose,
          child: Text(l10n.cancel),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s16),
            children: [
              Text(l10n.startBreakTitle, style: AppTypography.wizardStepTitle),
              const SizedBox(height: AppSpacing.s24),
              DateRowTile(
                label: l10n.startDateLabel,
                value: formatLocaleDate(state.startDate),
                valueColor: primaryColor,
                backgroundColor: fill,
                onTap: () => _showDatePicker(
                  context,
                  state.startDate,
                  minimumDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                  onDateChanged: widget.onStartDateChanged,
                ),
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
                      backgroundColor: fill,
                      onTap: () => _showDatePicker(
                        context,
                        state.endDate,
                        // Same-day break allowed (HAB-215) — a break's end date is inclusive of
                        // that whole day, so start == end already covers a single day off.
                        minimumDate: state.startDate,
                        onDateChanged: widget.onEndDateChanged,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedReveal(
                visible: state.nextShowupAfterEnd != null,
                child: Column(
                  key: const Key('break-next-showup-hint-row'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      _lastNextShowupAfterEnd == null
                          ? ''
                          : l10n.breakNextShowupHint(formatLocaleDate(_lastNextShowupAfterEnd!)),
                      key: const Key('break-next-showup-hint'),
                      style: AppTypography.caption.copyWith(color: HabitLoopColors.secondaryText(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  Expanded(child: Text(l10n.breakUntilPactEnds)),
                  CupertinoSwitch(
                    key: const Key('break-until-pact-ends-switch'),
                    value: state.untilPactEnds,
                    onChanged: widget.onUntilPactEndsChanged,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),
              CupertinoTextField(
                key: const Key('break-rationale-field'),
                controller: _rationaleController,
                placeholder: l10n.breakRationaleHint,
                maxLines: null,
                minLines: 3,
                onChanged: widget.onRationaleChanged,
              ),
              const SizedBox(height: AppSpacing.s24),
              if (state.submitError != null) ...[
                Text(
                  l10n.startBreakError,
                  style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              CupertinoButton.filled(
                key: const Key('break-submit-button'),
                onPressed: state.canSubmit ? widget.onSubmit : null,
                child: state.isSubmitting ? const CupertinoActivityIndicator() : Text(l10n.startBreakConfirm),
              ),
            ],
          ),
        ),
      ),
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
                    child: Text(AppLocalizations.of(ctx)!.pickerDone),
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

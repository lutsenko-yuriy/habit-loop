import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/habit_name_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/reminder_step_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/tappable_summary_row.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_page_scaffold.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_step_indicator.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_style.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';

// Android edit wizard: 3-page PageView (habit name → reminder → summary). × dismisses without saving.
class PactEditPageAndroid extends StatelessWidget {
  const PactEditPageAndroid({
    super.key,
    required this.state,
    required this.onHabitNameChanged,
    required this.onReminderOffsetChanged,
    required this.onClearReminder,
    required this.onPageChanged,
    required this.onJumpToStep,
    required this.onClose,
    required this.onSubmit,
    required this.isSaving,
    this.saveError,
  });

  final PactCreationState state;
  final ValueChanged<String> onHabitNameChanged;
  final ValueChanged<Duration> onReminderOffsetChanged;
  final VoidCallback onClearReminder;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onJumpToStep;
  final VoidCallback onClose;
  final VoidCallback onSubmit;
  final bool isSaving;
  final Object? saveError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = WizardStyle.material(context);
    final currentPage = _editPageIndex(state.currentStep);
    final isSummary = currentPage == kEditWizardPageCount - 1;
    final habitName = state.habitName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          habitName.isNotEmpty ? habitName : (isSummary ? l10n.wizardSummaryTitle : l10n.pactEditTitle),
        ),
        leading: IconButton(
          key: const Key('pact-edit-close-button'),
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          WizardStepIndicator(
            style: style,
            currentIndex: currentPage,
            stepCount: kEditWizardPageCount,
            onStepTapped: onJumpToStep,
            keyPrefix: 'pact-edit-step-indicator-android',
          ),
          Expanded(
            child: WizardPageScaffold(
              currentPage: currentPage,
              pageCount: kEditWizardPageCount,
              pageViewKey: const Key('pact-edit-pageview-android'),
              onPageChanged: onPageChanged,
              hintText: l10n.wizardSwipeHint,
              hintTextColor: style.hintTextColor,
              pageBuilder: (index, focusNode) => _buildPage(index, focusNode, l10n, style, context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, FocusNode focusNode, AppLocalizations l10n, WizardStyle style, BuildContext context) {
    switch (kEditSteps[index]) {
      case PactWizardStep.habitName:
        return HabitNameStepAndroid(
          state: state,
          l10n: l10n,
          onHabitNameChanged: onHabitNameChanged,
          showCommitmentWarning: false,
          focusNode: focusNode,
        );
      case PactWizardStep.reminder:
        return ReminderStepAndroid(
          state: state,
          l10n: l10n,
          onReminderOffsetChanged: onReminderOffsetChanged,
          onClearReminder: onClearReminder,
        );
      case PactWizardStep.summary:
        return _EditSummaryStepAndroid(
          state: state,
          l10n: l10n,
          style: style,
          onJumpToStep: onJumpToStep,
          onSubmit: onSubmit,
          isSaving: isSaving,
          saveError: saveError,
        );
      case PactWizardStep.duration:
      case PactWizardStep.showupDuration:
      case PactWizardStep.schedule:
        // kEditSteps only contains habitName/reminder/summary — these are unreachable.
        throw StateError('Unexpected edit wizard step: ${kEditSteps[index]}');
    }
  }
}

// ---------------------------------------------------------------------------
// Edit summary step (Android)
// ---------------------------------------------------------------------------

// Tappable habit name + reminder rows; save button always enabled (pre-populated from pact).
class _EditSummaryStepAndroid extends StatelessWidget {
  const _EditSummaryStepAndroid({
    required this.state,
    required this.l10n,
    required this.style,
    required this.onJumpToStep,
    required this.onSubmit,
    required this.isSaving,
    this.saveError,
  });

  final PactCreationState state;
  final AppLocalizations l10n;
  final WizardStyle style;
  final ValueChanged<int> onJumpToStep;
  final VoidCallback onSubmit;
  final bool isSaving;
  final Object? saveError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminderText = reminderDescription(l10n, state.reminderOffset);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            children: [
              const SizedBox(height: AppSpacing.s16),
              Text(l10n.wizardSummaryTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.s16),
              Container(
                key: const Key('pact-edit-summary-card'),
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(color: style.cardColor, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    TappableSummaryRow(
                      tapKey: 'edit-summary-row-tap-${PactWizardStep.habitName.analyticsName}',
                      label: l10n.summaryHabit,
                      value: state.habitName.isEmpty ? '—' : state.habitName,
                      labelColor: style.labelColor,
                      onTap: () => onJumpToStep(0),
                      divider: const Divider(height: 1),
                      useInkWell: true,
                    ),
                    TappableSummaryRow(
                      tapKey: 'edit-summary-row-tap-${PactWizardStep.reminder.analyticsName}',
                      label: l10n.summaryReminder,
                      value: reminderText,
                      labelColor: style.labelColor,
                      onTap: () => onJumpToStep(1),
                      useInkWell: true,
                    ),
                  ],
                ),
              ),
              if (saveError != null) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(
                  l10n.pactEditSaveError,
                  key: const Key('pact-edit-save-error'),
                  style: AppTypography.body.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('pact-edit-save-button'),
              onPressed: isSaving ? null : onSubmit,
              child: isSaving
                  ? SizedBox(
                      height: AppSpacing.s20,
                      width: AppSpacing.s20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimary),
                      ),
                    )
                  : Text(l10n.saveChanges),
            ),
          ),
        ),
      ],
    );
  }
}

int _editPageIndex(PactWizardStep step) {
  final idx = kEditSteps.indexOf(step);
  return idx < 0 ? 0 : idx;
}

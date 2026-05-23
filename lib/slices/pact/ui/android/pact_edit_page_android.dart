import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/habit_name_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/reminder_step_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/summary_row.dart';

/// Android edit-pact wizard.
///
/// A 3-page [PageView] containing:
/// - Page 0: habit name (commitment warning hidden — the user already committed)
/// - Page 1: reminder
/// - Page 2: summary with a "Save Changes" button
///
/// The step indicator shows 3 segments. The × button in the AppBar dismisses
/// the wizard without saving.
///
/// All state mutations are delegated to [PactEditViewModel] via callbacks
/// provided by [PactEditScreen].
class PactEditPageAndroid extends StatefulWidget {
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

  /// Called when the [PageView] page changes (swipe or programmatic).
  final ValueChanged<int> onPageChanged;

  /// Called with the edit-wizard page index (0 = habitName, 1 = reminder) when
  /// the user taps a summary row to jump back to that step.
  final ValueChanged<int> onJumpToStep;

  /// Called when the user taps the × button.
  final VoidCallback onClose;

  /// Called when the user taps "Save Changes" on the summary page.
  final VoidCallback onSubmit;

  /// True while the save operation is in progress.
  final bool isSaving;

  /// Non-null when the save operation failed; shown as an error message.
  final Object? saveError;

  @override
  State<PactEditPageAndroid> createState() => _PactEditPageAndroidState();
}

class _PactEditPageAndroidState extends State<PactEditPageAndroid> {
  late final PageController _pageController;
  late final FocusNode _habitNameFocusNode;

  /// True while a programmatic [PageController.animateToPage] call is in
  /// progress (e.g. after a step-indicator or summary-row tap).
  ///
  /// Intermediate [onPageChanged] callbacks fired during the animation must
  /// not update [state.currentStep] — doing so would cause the step indicator
  /// to flash through all pages between the origin and the destination.
  bool _isProgrammaticAnimation = false;

  static const _animationDuration = Duration(milliseconds: 300);
  static const _animationCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _editPageIndex(widget.state.currentStep));
    _habitNameFocusNode = FocusNode();
  }

  /// Animates to the new page when [PactEditViewModel.goToPage] changes
  /// [state.currentStep] programmatically (e.g. after a summary-row jump).
  @override
  void didUpdateWidget(covariant PactEditPageAndroid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = _editPageIndex(widget.state.currentStep);
    if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
      _isProgrammaticAnimation = true;
      unawaited(
        _pageController
            .animateToPage(targetPage, duration: _animationDuration, curve: _animationCurve)
            .whenComplete(() {
          if (mounted) _isProgrammaticAnimation = false;
        }),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _habitNameFocusNode.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    // Suppress view-model updates for intermediate pages during a programmatic
    // jump — the target step is already set by the jump callback.
    if (!_isProgrammaticAnimation) {
      widget.onPageChanged(page);
    }
    if (page == 0) {
      _habitNameFocusNode.requestFocus();
    } else {
      _habitNameFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentPage = _editPageIndex(widget.state.currentStep);
    final isSummary = currentPage == kEditWizardPageCount - 1;
    final habitName = widget.state.habitName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          habitName.isNotEmpty ? habitName : (isSummary ? l10n.wizardSummaryTitle : l10n.pactEditTitle),
        ),
        leading: IconButton(
          key: const Key('pact-edit-close-button'),
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _EditStepIndicator(currentPage: currentPage, onStepTapped: widget.onJumpToStep),
          Expanded(
            child: PageView(
              key: const Key('pact-edit-pageview-android'),
              controller: _pageController,
              onPageChanged: _handlePageChanged,
              children: _buildPages(l10n),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              l10n.wizardSwipeHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPages(AppLocalizations l10n) => [
        HabitNameStepAndroid(
          state: widget.state,
          l10n: l10n,
          onHabitNameChanged: widget.onHabitNameChanged,
          showCommitmentWarning: false,
          focusNode: _habitNameFocusNode,
        ),
        ReminderStepAndroid(
          state: widget.state,
          l10n: l10n,
          onReminderOffsetChanged: widget.onReminderOffsetChanged,
          onClearReminder: widget.onClearReminder,
        ),
        _EditSummaryStepAndroid(
          state: widget.state,
          l10n: l10n,
          onJumpToStep: widget.onJumpToStep,
          onSubmit: widget.onSubmit,
          isSaving: widget.isSaving,
          saveError: widget.saveError,
        ),
      ];
}

// ---------------------------------------------------------------------------
// Edit summary step (Android)
// ---------------------------------------------------------------------------

/// Summary page for the edit wizard (Android).
///
/// Shows only the two editable fields (habit name and reminder) as tappable
/// rows, so the user can jump back to revise before saving.
class _EditSummaryStepAndroid extends StatelessWidget {
  const _EditSummaryStepAndroid({
    required this.state,
    required this.l10n,
    required this.onJumpToStep,
    required this.onSubmit,
    required this.isSaving,
    this.saveError,
  });

  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<int> onJumpToStep;
  final VoidCallback onSubmit;
  final bool isSaving;
  final Object? saveError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminderText = reminderDescription(l10n, state.reminderOffset);
    final labelColor = theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 16),
              Text(l10n.wizardSummaryTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Container(
                key: const Key('pact-edit-summary-card'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _TappableSummaryRow(
                      stepName: PactWizardStep.habitName.analyticsName,
                      label: l10n.summaryHabit,
                      value: state.habitName.isEmpty ? '—' : state.habitName,
                      labelColor: labelColor,
                      onTap: () => onJumpToStep(0), // edit page 0 = habitName
                    ),
                    _TappableSummaryRow(
                      stepName: PactWizardStep.reminder.analyticsName,
                      label: l10n.summaryReminder,
                      value: reminderText,
                      labelColor: labelColor,
                      onTap: () => onJumpToStep(1), // edit page 1 = reminder
                      isLast: true,
                    ),
                  ],
                ),
              ),
              if (saveError != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.pactEditSaveError,
                  key: const Key('pact-edit-save-error'),
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('pact-edit-save-button'),
              onPressed: isSaving ? null : onSubmit,
              child: isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
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

// ---------------------------------------------------------------------------
// Shared tappable summary row (Android)
// ---------------------------------------------------------------------------

class _TappableSummaryRow extends StatelessWidget {
  final String stepName;
  final String label;
  final String value;
  final Color labelColor;
  final VoidCallback onTap;

  /// When `false`, a [Divider] is rendered below the row as a separator.
  /// Set to `true` on the last row in a group to suppress the trailing divider.
  final bool isLast;

  const _TappableSummaryRow({
    required this.stepName,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          key: Key('edit-summary-row-tap-$stepName'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SummaryRow(label: label, value: value, labelColor: labelColor),
                ),
                Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit step indicator (3 segments, Android)
// ---------------------------------------------------------------------------

class _EditStepIndicator extends StatelessWidget {
  final int currentPage;

  /// Called with the tapped page index when the user taps a segment.
  final ValueChanged<int> onStepTapped;

  const _EditStepIndicator({required this.currentPage, required this.onStepTapped});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('pact-edit-step-indicator-android'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(kEditWizardPageCount, (index) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onStepTapped(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                key: Key('pact-edit-step-indicator-android-segment-$index'),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: index < currentPage
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : index == currentPage
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Returns the [PageView] page index (0-2) for [step] in the edit wizard.
int _editPageIndex(PactWizardStep step) {
  final idx = kEditSteps.indexOf(step);
  return idx < 0 ? 0 : idx;
}

import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, Icon, Icons, Material, MaterialType, Theme;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/summary_row.dart';
import 'package:habit_loop/slices/pact/ui/ios/habit_name_step_ios.dart';
import 'package:habit_loop/slices/pact/ui/ios/reminder_step_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

// iOS edit wizard: 3-page PageView (habit name → reminder → summary). × dismisses without saving.
class PactEditPageIos extends StatefulWidget {
  const PactEditPageIos({
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
  State<PactEditPageIos> createState() => _PactEditPageIosState();
}

class _PactEditPageIosState extends State<PactEditPageIos> {
  late final PageController _pageController;
  late final FocusNode _habitNameFocusNode;

  // Guards against mid-animation onPageChanged callbacks flashing through intermediate steps.
  bool _isProgrammaticAnimation = false;

  static const _animationDuration = Duration(milliseconds: 300);
  static const _animationCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _editPageIndex(widget.state.currentStep));
    _habitNameFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant PactEditPageIos oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = _editPageIndex(widget.state.currentStep);
    if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
      // Skip mid-swipe: animateToPage would fight the gesture and suppress onPageChanged.
      if (_isProgrammaticAnimation || _pageController.position.isScrollingNotifier.value) return;
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

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: CupertinoButton(
          key: const Key('pact-edit-close-button'),
          padding: EdgeInsets.zero,
          onPressed: widget.onClose,
          child: const Icon(CupertinoIcons.xmark),
        ),
        middle: Text(
          habitName.isNotEmpty ? habitName : (isSummary ? l10n.wizardSummaryTitle : l10n.pactEditTitle),
        ),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              _EditStepIndicator(currentPage: currentPage, onStepTapped: widget.onJumpToStep),
              Expanded(
                child: PageView(
                  key: const Key('pact-edit-pageview-ios'),
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
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPages(AppLocalizations l10n) => [
        HabitNameStepIos(
          state: widget.state,
          l10n: l10n,
          onHabitNameChanged: widget.onHabitNameChanged,
          showCommitmentWarning: false,
          focusNode: _habitNameFocusNode,
        ),
        ReminderStepIos(
          state: widget.state,
          l10n: l10n,
          onReminderOffsetChanged: widget.onReminderOffsetChanged,
          onClearReminder: widget.onClearReminder,
        ),
        _EditSummaryStepIos(
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
// Edit summary step (iOS)
// ---------------------------------------------------------------------------

// Tappable habit name + reminder rows; save button always enabled (pre-populated from pact).
class _EditSummaryStepIos extends StatelessWidget {
  const _EditSummaryStepIos({
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
    final reminderText = reminderDescription(l10n, state.reminderOffset);
    final labelColor = CupertinoColors.systemGrey.resolveFrom(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 16),
              Text(
                l10n.wizardSummaryTitle,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                key: const Key('pact-edit-summary-card'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
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
                    Divider(color: CupertinoColors.separator.resolveFrom(context), height: 1),
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
                  style: TextStyle(
                    color: CupertinoColors.destructiveRed.resolveFrom(context),
                    fontSize: 14,
                  ),
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
            child: CupertinoButton.filled(
              key: const Key('pact-edit-save-button'),
              onPressed: isSaving ? null : onSubmit,
              child: isSaving ? const CupertinoActivityIndicator(color: CupertinoColors.white) : Text(l10n.saveChanges),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared tappable summary row (iOS)
// ---------------------------------------------------------------------------

class _TappableSummaryRow extends StatelessWidget {
  final String stepName;
  final String label;
  final String value;
  final Color labelColor;
  final VoidCallback onTap;
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
    return GestureDetector(
      key: Key('edit-summary-row-tap-$stepName'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SummaryRow(label: label, value: value, labelColor: labelColor),
              ),
              Icon(Icons.chevron_right, size: 18, color: CupertinoColors.systemGrey.resolveFrom(context)),
            ],
          ),
          if (!isLast) Divider(color: CupertinoColors.separator.resolveFrom(context), height: 1),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit step indicator (3 segments)
// ---------------------------------------------------------------------------

class _EditStepIndicator extends StatelessWidget {
  final int currentPage;

  final ValueChanged<int> onStepTapped;

  const _EditStepIndicator({required this.currentPage, required this.onStepTapped});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('pact-edit-step-indicator-ios'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(kEditWizardPageCount, (index) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onStepTapped(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                key: Key('pact-edit-step-indicator-ios-segment-$index'),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: index < currentPage
                      ? HabitLoopColors.primary.withValues(alpha: 0.3)
                      : index == currentPage
                          ? HabitLoopColors.primary
                          : CupertinoColors.tertiarySystemFill.resolveFrom(context),
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

int _editPageIndex(PactWizardStep step) {
  final idx = kEditSteps.indexOf(step);
  return idx < 0 ? 0 : idx;
}

import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/habit_name_step_ios.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_duration_step_ios.dart';
import 'package:habit_loop/slices/pact/ui/ios/reminder_step_ios.dart';
import 'package:habit_loop/slices/pact/ui/ios/schedule_step_ios.dart';
import 'package:habit_loop/slices/pact/ui/ios/showup_duration_step_ios.dart';
import 'package:habit_loop/slices/pact/ui/ios/summary_step_ios.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

/// iOS pact creation wizard.
///
/// Uses a [PageView] to allow the user to swipe between the six wizard steps:
/// habit name → pact duration → showup duration → schedule → reminder → summary.
///
/// Navigation model:
/// - Swipe left/right to move between pages (no Next/Back buttons).
/// - The nav bar always shows a × close button that dismisses the wizard.
/// - The nav bar title shows the habit name once entered, otherwise the screen
///   title (or "Summary" on the last page).
/// - On the summary page a "Create Pact" button appears at the bottom.
///
/// The parent ([PactCreationScreen]) wires all callbacks and provides the
/// complete [PactCreationState] on every rebuild. When [state.currentStep]
/// changes programmatically (e.g. summary-row jump), [didUpdateWidget]
/// animates the [PageController] to the new page.
class PactCreationPageIos extends StatefulWidget {
  const PactCreationPageIos({
    super.key,
    required this.state,
    required this.onHabitNameChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onShowupDurationChanged,
    required this.onScheduleTypeChanged,
    required this.onScheduleChanged,
    required this.onReminderOffsetChanged,
    required this.onClearReminder,
    required this.onPageChanged,
    required this.onJumpToStep,
    required this.onClose,
    required this.onSubmit,
  });

  final PactCreationState state;
  final ValueChanged<String> onHabitNameChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<Duration> onShowupDurationChanged;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;
  final ValueChanged<Duration> onReminderOffsetChanged;
  final VoidCallback onClearReminder;

  /// Called whenever the visible page changes (swipe or programmatic).
  /// Wired to [PactCreationViewModel.goToPage] in [PactCreationScreen].
  final ValueChanged<int> onPageChanged;

  /// Called when the user taps a row on the summary page to jump back.
  /// The parent updates [state.currentStep]; [didUpdateWidget] then animates
  /// the [PageController] to match.
  final ValueChanged<int> onJumpToStep;

  /// Called when the user taps the × button to dismiss the wizard.
  final VoidCallback onClose;

  /// Called when "Create Pact" is tapped on the summary page.
  final VoidCallback onSubmit;

  @override
  State<PactCreationPageIos> createState() => _PactCreationPageIosState();
}

class _PactCreationPageIosState extends State<PactCreationPageIos> {
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
    _pageController = PageController(initialPage: widget.state.currentStep.value);
    _habitNameFocusNode = FocusNode();
  }

  /// Animates to the new page when the ViewModel's currentStep changes
  /// (e.g. after a summary-row jump sets a different step).
  @override
  void didUpdateWidget(covariant PactCreationPageIos oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = widget.state.currentStep.value;
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
    final step = widget.state.currentStep;
    final isLastStep = step.isLast;
    final habitName = widget.state.habitName;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          key: const Key('pact-creation-close-button'),
          padding: EdgeInsets.zero,
          onPressed: widget.onClose,
          child: const Icon(CupertinoIcons.xmark),
        ),
        middle: Text(
          habitName.isNotEmpty ? habitName : (isLastStep ? l10n.wizardSummaryTitle : l10n.pactCreationTitle),
        ),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              _StepIndicator(currentStep: step, onStepTapped: widget.onJumpToStep),
              Expanded(
                child: PageView(
                  key: const Key('pact-creation-pageview-ios'),
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
          focusNode: _habitNameFocusNode,
        ),
        PactDurationStepIos(
          state: widget.state,
          l10n: l10n,
          onStartDateChanged: widget.onStartDateChanged,
          onEndDateChanged: widget.onEndDateChanged,
          onShowupDurationChanged: widget.onShowupDurationChanged,
        ),
        ShowupDurationStepIos(
          state: widget.state,
          l10n: l10n,
          onChanged: widget.onShowupDurationChanged,
        ),
        ScheduleStepIos(
          state: widget.state,
          l10n: l10n,
          onScheduleTypeChanged: widget.onScheduleTypeChanged,
          onScheduleChanged: widget.onScheduleChanged,
        ),
        ReminderStepIos(
          state: widget.state,
          l10n: l10n,
          onReminderOffsetChanged: widget.onReminderOffsetChanged,
          onClearReminder: widget.onClearReminder,
        ),
        SummaryStepIos(
          state: widget.state,
          l10n: l10n,
          onJumpToStep: widget.onJumpToStep,
          onSubmit: widget.onSubmit,
          isComplete: widget.state.builder.isComplete,
        ),
      ];
}

// ---------------------------------------------------------------------------
// Step indicator bar
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  final PactWizardStep currentStep;

  /// Called with the tapped page index when the user taps a segment.
  final ValueChanged<int> onStepTapped;

  const _StepIndicator({required this.currentStep, required this.onStepTapped});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('pact-creation-step-indicator-ios'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(PactWizardStep.count, (index) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onStepTapped(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                key: Key('pact-creation-step-indicator-ios-segment-$index'),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: index < currentStep.index
                      ? HabitLoopColors.primary.withValues(alpha: 0.3)
                      : index == currentStep.index
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

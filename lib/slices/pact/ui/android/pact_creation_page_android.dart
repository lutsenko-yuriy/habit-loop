import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/habit_name_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_duration_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/reminder_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/schedule_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/showup_duration_step_android.dart';
import 'package:habit_loop/slices/pact/ui/android/summary_step_android.dart';

/// Android pact creation wizard.
///
/// Uses a [PageView] with six wizard steps:
/// habit name → pact duration → showup duration → schedule → reminder → summary.
///
/// See [PactCreationPageIos] for the shared navigation model. This widget
/// follows the same pattern but uses Material widgets throughout.
class PactCreationPageAndroid extends StatefulWidget {
  const PactCreationPageAndroid({
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

  /// Called whenever the visible page changes. Wired to
  /// [PactCreationViewModel.goToPage] in [PactCreationScreen].
  final ValueChanged<int> onPageChanged;

  /// Called when the user taps a summary row to jump back to a step.
  final ValueChanged<int> onJumpToStep;

  /// Called when the user taps the × button to dismiss the wizard.
  final VoidCallback onClose;

  /// Called when "Create Pact" is tapped on the summary page.
  final VoidCallback onSubmit;

  @override
  State<PactCreationPageAndroid> createState() => _PactCreationPageAndroidState();
}

class _PactCreationPageAndroidState extends State<PactCreationPageAndroid> {
  late final PageController _pageController;
  late final FocusNode _habitNameFocusNode;

  static const _animationDuration = Duration(milliseconds: 300);
  static const _animationCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.state.currentStep.value);
    _habitNameFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant PactCreationPageAndroid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = widget.state.currentStep.value;
    if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
      unawaited(
        _pageController.animateToPage(
          targetPage,
          duration: _animationDuration,
          curve: _animationCurve,
        ),
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
    widget.onPageChanged(page);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          habitName.isNotEmpty ? habitName : (isLastStep ? l10n.wizardSummaryTitle : l10n.pactCreationTitle),
        ),
        leading: IconButton(
          key: const Key('pact-creation-close-button'),
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: step, onStepTapped: widget.onJumpToStep),
          Expanded(
            child: PageView(
              key: const Key('pact-creation-pageview-android'),
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
          focusNode: _habitNameFocusNode,
        ),
        PactDurationStepAndroid(
          state: widget.state,
          l10n: l10n,
          onStartDateChanged: widget.onStartDateChanged,
          onEndDateChanged: widget.onEndDateChanged,
        ),
        ShowupDurationStepAndroid(
          state: widget.state,
          l10n: l10n,
          onChanged: widget.onShowupDurationChanged,
        ),
        ScheduleStepAndroid(
          state: widget.state,
          l10n: l10n,
          onScheduleTypeChanged: widget.onScheduleTypeChanged,
          onScheduleChanged: widget.onScheduleChanged,
        ),
        ReminderStepAndroid(
          state: widget.state,
          l10n: l10n,
          onReminderOffsetChanged: widget.onReminderOffsetChanged,
          onClearReminder: widget.onClearReminder,
        ),
        SummaryStepAndroid(
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
    final theme = Theme.of(context);
    return Padding(
      key: const Key('pact-creation-step-indicator-android'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(PactWizardStep.count, (index) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onStepTapped(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                key: Key('pact-creation-step-indicator-android-segment-$index'),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: index < currentStep.index
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : index == currentStep.index
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

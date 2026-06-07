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

// iOS creation wizard: 6-page PageView (habit name → duration → showup duration → schedule → reminder → summary).
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

  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onJumpToStep;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  State<PactCreationPageIos> createState() => _PactCreationPageIosState();
}

class _PactCreationPageIosState extends State<PactCreationPageIos> {
  late final PageController _pageController;
  late final FocusNode _habitNameFocusNode;

  // Guards against mid-animation onPageChanged callbacks flashing through intermediate steps.
  bool _isProgrammaticAnimation = false;

  static const _animationDuration = Duration(milliseconds: 300);
  static const _animationCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.state.currentStep.value);
    _habitNameFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant PactCreationPageIos oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = widget.state.currentStep.value;
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
    final step = widget.state.currentStep;
    final isLastStep = step.isLast;
    final habitName = widget.state.habitName;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
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

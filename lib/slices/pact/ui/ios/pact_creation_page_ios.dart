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
/// - Swipe left/right or use the "Next" / "Back" buttons.
/// - Back button is shown in the nav bar for pages 1–5; on page 0 the system
///   navigator provides the back gesture / button.
/// - On the summary page the bottom bar shows "Create Pact" instead of "Next".
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

  /// Called when "Create Pact" is tapped on the summary page.
  final VoidCallback onSubmit;

  @override
  State<PactCreationPageIos> createState() => _PactCreationPageIosState();
}

class _PactCreationPageIosState extends State<PactCreationPageIos> {
  late final PageController _pageController;

  static const _animationDuration = Duration(milliseconds: 300);
  static const _animationCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.state.currentStep.value);
  }

  /// Animates to the new page when the ViewModel's currentStep changes
  /// (e.g. after a summary-row jump sets a different step).
  @override
  void didUpdateWidget(covariant PactCreationPageIos oldWidget) {
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
    super.dispose();
  }

  void _goToNextPage() => _pageController.nextPage(duration: _animationDuration, curve: _animationCurve);

  void _goToPreviousPage() => _pageController.previousPage(duration: _animationDuration, curve: _animationCurve);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final step = widget.state.currentStep;
    final isLastStep = step.isLast;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        middle: Text(isLastStep ? l10n.wizardSummaryTitle : l10n.pactCreationTitle),
        leading: step.isFirst
            ? null // system back button visible; tapping pops the wizard
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _goToPreviousPage,
                child: Text(l10n.back),
              ),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              _StepIndicator(currentStep: step),
              Expanded(
                child: PageView(
                  key: const Key('pact-creation-pageview-ios'),
                  controller: _pageController,
                  onPageChanged: widget.onPageChanged,
                  children: _buildPages(l10n),
                ),
              ),
              _BottomBar(
                isLastStep: isLastStep,
                l10n: l10n,
                onNext: _goToNextPage,
                onSubmit: widget.onSubmit,
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
        ),
      ];
}

// ---------------------------------------------------------------------------
// Step indicator bar
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  final PactWizardStep currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('pact-creation-step-indicator-ios'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(PactWizardStep.count, (index) {
          return Expanded(
            child: Container(
              key: Key('pact-creation-step-indicator-ios-segment-$index'),
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: index <= currentStep.index
                    ? HabitLoopColors.primary
                    : CupertinoColors.tertiarySystemFill.resolveFrom(context),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  final bool isLastStep;
  final AppLocalizations l10n;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.isLastStep,
    required this.l10n,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: isLastStep
            ? CupertinoButton.filled(
                key: const Key('pact-creation-create-button'),
                onPressed: onSubmit,
                child: Text(l10n.createPactConfirm),
              )
            : CupertinoButton.filled(
                key: const Key('pact-creation-next-button'),
                onPressed: onNext,
                child: Text(l10n.next),
              ),
      ),
    );
  }
}

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_creation_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/commitment_dialog_content.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_creation_page_ios.dart';

class PactCreationScreen extends ConsumerStatefulWidget {
  const PactCreationScreen({super.key});

  @override
  ConsumerState<PactCreationScreen> createState() => _PactCreationScreenState();
}

class _PactCreationScreenState extends ConsumerState<PactCreationScreen> {
  /// `true` after a pact has been successfully created so that the `PopScope`
  /// does not fire the abandoned event on the programmatic [Navigator.pop]
  /// that follows a successful submission.
  bool _pactCreated = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const PactCreationAnalyticsScreen()),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary-page jump
  // ---------------------------------------------------------------------------

  void _onJumpToStep(int page) {
    final vm = ref.read(pactCreationViewModelProvider.notifier);
    vm.markSummaryJumped();
    vm.goToPage(page);

    // Fire analytics: which step the user jumped to, in 'creation' mode.
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            PactWizardStepJumpedEvent(
              stepName: page < PactWizardStep.values.length ? PactWizardStep.values[page].analyticsName : 'unknown',
              mode: 'creation',
            ),
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // Commitment dialog + submission
  // ---------------------------------------------------------------------------

  /// Reads the EXP-003 variant from Remote Config and shows the commitment
  /// confirmation dialog. On accept, submits the pact and pops the screen.
  Future<void> _onSubmit() async {
    final variant =
        ref.read(remoteConfigServiceProvider).getString(RemoteConfigDefaults.exp003CommitmentConfirmationKey);

    bool accepted = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: CommitmentDialogContent(
              variant: variant,
              habitName: ref.read(pactCreationViewModelProvider).habitName,
              onAccept: () {
                accepted = true;
                Navigator.of(dialogContext).pop();
              },
              onDismiss: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ),
        );
      },
    );

    if (!accepted) {
      // User dismissed the dialog — fire the abandonment analytics event.
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
              PactCommitmentDialogDismissedEvent(variant: variant),
            ),
      );
      return;
    }

    // User confirmed — submit the pact.
    final vm = ref.read(pactCreationViewModelProvider.notifier);
    await vm.submit(commitmentVariant: variant);

    if (!mounted) return;
    if (ref.read(pactCreationViewModelProvider).submitError != null) return;

    _pactCreated = true;
    ref.invalidate(hasActivePactsProvider);
    unawaited(ref.read(dashboardViewModelProvider.notifier).load());
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pactCreationViewModelProvider);
    final vm = ref.read(pactCreationViewModelProvider.notifier);

    final Widget page;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      page = PactCreationPageIos(
        state: state,
        onHabitNameChanged: vm.setHabitName,
        onStartDateChanged: vm.setStartDate,
        onEndDateChanged: vm.setEndDate,
        onShowupDurationChanged: vm.setShowupDuration,
        onScheduleTypeChanged: vm.setScheduleType,
        onScheduleChanged: vm.setSchedule,
        onReminderOffsetChanged: vm.setReminderOffset,
        onClearReminder: vm.clearReminderOffset,
        onPageChanged: vm.goToPage,
        onJumpToStep: _onJumpToStep,
        onSubmit: _onSubmit,
      );
    } else {
      page = PactCreationPageAndroid(
        state: state,
        onHabitNameChanged: vm.setHabitName,
        onStartDateChanged: vm.setStartDate,
        onEndDateChanged: vm.setEndDate,
        onShowupDurationChanged: vm.setShowupDuration,
        onScheduleTypeChanged: vm.setScheduleType,
        onScheduleChanged: vm.setSchedule,
        onReminderOffsetChanged: vm.setReminderOffset,
        onClearReminder: vm.clearReminderOffset,
        onPageChanged: vm.goToPage,
        onJumpToStep: _onJumpToStep,
        onSubmit: _onSubmit,
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_pactCreated) {
          unawaited(
            ref.read(analyticsServiceProvider).logEvent(
                  PactWizardAbandonedEvent(
                    mode: 'creation',
                    lastStep: state.currentStep.analyticsName,
                  ),
                ),
          );
        }
      },
      child: page,
    );
  }
}

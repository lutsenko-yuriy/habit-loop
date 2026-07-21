import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_edit_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_view_model.dart';
import 'package:habit_loop/slices/pact/ui/ios/pact_edit_page_ios.dart';
import 'package:habit_loop/theme/spacing.dart';

/// Screen orchestrator for the edit-pact wizard.
///
/// Responsibilities:
/// - Calls [PactEditViewModel.load] on first mount to seed wizard state.
/// - Logs the [PactEditAnalyticsScreen] screen view.
/// - Handles loading / error states, showing spinners or error messages.
/// - Delegates all data mutations to [PactEditViewModel] via callbacks on the
///   platform page widget.
/// - Fires [PactWizardAbandonedEvent] via [PopScope] when the user dismisses
///   the wizard without saving (swipe-back or × button before save completes).
/// - On successful save: pops the route so the caller can refresh.
///
/// Callers must push this screen and `await` its result, then reload the pact
/// detail screen on pop to reflect any saved changes.
class PactEditScreen extends ConsumerStatefulWidget {
  const PactEditScreen({super.key, required this.pactId});

  /// The ID of the pact to edit.
  final String pactId;

  @override
  ConsumerState<PactEditScreen> createState() => _PactEditScreenState();
}

class _PactEditScreenState extends ConsumerState<PactEditScreen> {
  /// `true` after a successful save so that [PopScope] does not fire the
  /// abandoned event on the programmatic [Navigator.pop] that follows.
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        unawaited(
          ref.read(analyticsServiceProvider).logScreenView(const PactEditAnalyticsScreen()),
        );
        unawaited(
          ref.read(pactEditViewModelProvider(widget.pactId).notifier).load(),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary-page step jump
  // ---------------------------------------------------------------------------

  void _onJumpToStep(int editPage) {
    final vm = ref.read(pactEditViewModelProvider(widget.pactId).notifier);
    vm.markSummaryJumped();
    vm.goToPage(editPage);

    // Fire analytics: which step the user jumped to, in 'editing' mode.
    final stepName = editPage < kEditSteps.length ? kEditSteps[editPage].analyticsName : 'unknown';
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            PactWizardStepJumpedEvent(
              stepName: stepName,
              mode: 'editing',
            ),
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _onSubmit() async {
    final vm = ref.read(pactEditViewModelProvider(widget.pactId).notifier);
    await vm.save();

    if (!mounted) return;

    final state = ref.read(pactEditViewModelProvider(widget.pactId));
    if (state.saveError != null) return; // error displayed in the page

    _saved = true;
    Navigator.of(context).pop(true); // pop with `true` to signal a successful save
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(pactEditViewModelProvider(widget.pactId));

    // Loading state.
    if (editState.isLoading || editState.wizardState == null) {
      return _buildLoading(context, editState);
    }

    final wizardState = editState.wizardState!;
    final vm = ref.read(pactEditViewModelProvider(widget.pactId).notifier);

    final Widget page;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      page = PactEditPageIos(
        state: wizardState,
        onHabitNameChanged: vm.setHabitName,
        onReminderOffsetChanged: vm.setReminderOffset,
        onClearReminder: vm.clearReminderOffset,
        onPageChanged: vm.goToPage,
        onJumpToStep: _onJumpToStep,
        onClose: () => Navigator.of(context).pop(),
        onSubmit: _onSubmit,
        isSaving: editState.isSaving,
        saveError: editState.saveError,
      );
    } else {
      page = PactEditPageAndroid(
        state: wizardState,
        onHabitNameChanged: vm.setHabitName,
        onReminderOffsetChanged: vm.setReminderOffset,
        onClearReminder: vm.clearReminderOffset,
        onPageChanged: vm.goToPage,
        onJumpToStep: _onJumpToStep,
        onClose: () => Navigator.of(context).pop(),
        onSubmit: _onSubmit,
        isSaving: editState.isSaving,
        saveError: editState.saveError,
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_saved) {
          unawaited(
            ref.read(analyticsServiceProvider).logEvent(
                  PactWizardAbandonedEvent(
                    mode: 'editing',
                    lastStep: wizardState.currentStep.analyticsName,
                  ),
                ),
          );
        }
      },
      child: page,
    );
  }

  // ---------------------------------------------------------------------------
  // Loading / error placeholder
  // ---------------------------------------------------------------------------

  Widget _buildLoading(BuildContext context, PactEditWizardState state) {
    if (state.loadError != null) {
      return _ErrorScaffold(onClose: () => Navigator.of(context).pop());
    }

    // Show a minimal scaffold with a spinner while load() is in flight.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const _LoadingScaffoldiOS();
    }
    return const _LoadingScaffoldAndroid();
  }
}

// ---------------------------------------------------------------------------
// Loading scaffolds
// ---------------------------------------------------------------------------

class _LoadingScaffoldiOS extends StatelessWidget {
  const _LoadingScaffoldiOS();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator.adaptive());
  }
}

class _LoadingScaffoldAndroid extends StatelessWidget {
  const _LoadingScaffoldAndroid();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// Error scaffold
// ---------------------------------------------------------------------------

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: AppSpacing.s16),
          TextButton(onPressed: onClose, child: Text(l10n.cancel)),
        ],
      ),
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) return body;
    return Scaffold(body: body);
  }
}

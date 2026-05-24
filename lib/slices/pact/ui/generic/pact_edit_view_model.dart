import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

/// Maps the 3 edit wizard page indices to their corresponding [PactWizardStep]
/// values.
///
/// The edit wizard skips duration, showup-duration, and schedule steps, which
/// the user cannot change after a pact is created.
///
/// | PageView index | Step                  |
/// |---|---|
/// | 0 | [PactWizardStep.habitName] |
/// | 1 | [PactWizardStep.reminder]  |
/// | 2 | [PactWizardStep.summary]   |
///
/// Platform page widgets import this constant to drive their step indicators
/// and [PageController] target-page computations.
const List<PactWizardStep> kEditSteps = [
  PactWizardStep.habitName,
  PactWizardStep.reminder,
  PactWizardStep.summary,
];

/// Number of pages in the edit wizard (= [kEditSteps.length]).
const int kEditWizardPageCount = 3;

// ---------------------------------------------------------------------------
// Clock provider — overridable in tests
// ---------------------------------------------------------------------------

/// Provides the current date for the edit wizard.
///
/// Overridable in tests to make the initial [PactBuilder] snapshot
/// deterministic without relying on [DateTime.now].
final pactEditTodayProvider = Provider<DateTime>((ref) => DateTime.now());

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Combined loading / wizard / saving state for the edit-pact wizard.
///
/// [wizardState] and [originalPact] are `null` until [PactEditViewModel.load]
/// completes successfully; the UI should show a loading indicator or error
/// screen when they are null.
class PactEditWizardState {
  const PactEditWizardState({
    this.isLoading = false,
    this.loadError,
    this.wizardState,
    this.originalPact,
    this.isSaving = false,
    this.saveError,
  });

  /// True while [PactEditViewModel.load] is running.
  final bool isLoading;

  /// Non-null when [PactEditViewModel.load] failed.
  final Object? loadError;

  /// The wizard navigation state seeded from the original pact.
  ///
  /// `null` until [PactEditViewModel.load] completes successfully.
  final PactCreationState? wizardState;

  /// The pact as it existed before the user made any edits.
  ///
  /// `null` until [PactEditViewModel.load] completes successfully.
  /// Used in [PactEditViewModel.save] to compute which fields changed.
  final Pact? originalPact;

  /// True while [PactEditViewModel.save] is running.
  final bool isSaving;

  /// Non-null when [PactEditViewModel.save] failed.
  final Object? saveError;

  PactEditWizardState copyWith({
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
    PactCreationState? wizardState,
    Pact? originalPact,
    bool? isSaving,
    Object? saveError,
    bool clearSaveError = false,
  }) {
    return PactEditWizardState(
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      wizardState: wizardState ?? this.wizardState,
      originalPact: originalPact ?? this.originalPact,
      isSaving: isSaving ?? this.isSaving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provides a [PactEditViewModel] instance keyed by pact ID.
final pactEditViewModelProvider = NotifierProviderFamily<PactEditViewModel, PactEditWizardState, String>(
  PactEditViewModel.new,
);

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

/// View model for the edit-pact wizard.
///
/// The edit wizard lets users update two fields on an existing active pact:
/// the habit name and the reminder offset. All other pact fields (dates,
/// schedule, showup duration) are fixed after creation.
///
/// ## Lifecycle
///
/// 1. Call [load] on screen init to seed [PactEditWizardState.wizardState]
///    from the persisted pact.
/// 2. Use the field setters ([setHabitName], [setReminderOffset],
///    [clearReminderOffset]) to mutate the wizard state as the user types.
/// 3. Call [goToPage] from the [PageView.onPageChanged] callback to keep
///    [PactCreationState.currentStep] in sync with the visible page.
/// 4. Call [markSummaryJumped] when the user taps a summary row to jump back
///    to a step before saving.
/// 5. Call [save] from the summary page's "Save Changes" button to persist
///    the changes, reschedule reminders, and fire analytics.
class PactEditViewModel extends FamilyNotifier<PactEditWizardState, String> {
  @override
  PactEditWizardState build(String pactId) => const PactEditWizardState();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Applies [update] to [PactEditWizardState.wizardState].
  ///
  /// A no-op when [wizardState] is `null` (i.e. before [load] completes),
  /// which prevents crashes from UI callbacks that fire before load finishes.
  void _updateWizardState(PactCreationState Function(PactCreationState) update) {
    final ws = state.wizardState;
    if (ws == null) return;
    state = state.copyWith(wizardState: update(ws));
  }

  /// Routes all builder-level mutations through [_updateWizardState].
  void _updateBuilder(PactBuilder Function(PactBuilder) update) {
    _updateWizardState((ws) => ws.copyWith(builder: update(ws.builder)));
  }

  // ---------------------------------------------------------------------------
  // load
  // ---------------------------------------------------------------------------

  /// Loads the pact from the repository and seeds [PactEditWizardState.wizardState].
  ///
  /// A [PactBuilder] is constructed from the pact via [PactBuilder.fromPact],
  /// and a [PactCreationState] is initialised from that builder so the edit
  /// wizard shares the same state structure as the creation wizard.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearLoadError: true);
    try {
      unawaited(ref.read(crashlyticsServiceProvider).log('screen: pact_edit(id=$arg)'));
      unawaited(ref.read(logServiceProvider).info('pact_edit: load(id=$arg)'));

      final pact = await ref.read(pactServiceProvider).getPact(arg);
      if (pact == null) {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Pact not found: $arg'),
        );
        return;
      }

      final today = ref.read(pactEditTodayProvider);

      // Track legacy schedule usage so we know when it is safe to drop the
      // legacy codec branches.  Logged only — no PII (schedule type is an enum).
      if (pact.schedule is! SlotSchedule) {
        unawaited(
          ref.read(logServiceProvider).info(
                'pact_edit: legacy schedule migration: type=${pact.schedule.runtimeType} id=$arg',
              ),
        );
      }

      final builder = PactBuilder.fromPact(pact, today: today);
      final wizardState = PactCreationState(
        today: today,
        builder: builder,
        currentStep: PactWizardStep.habitName,
      );

      state = state.copyWith(
        isLoading: false,
        wizardState: wizardState,
        originalPact: pact,
      );
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('pact_edit_load_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Field setters
  // ---------------------------------------------------------------------------

  /// Updates the habit name in the wizard state.
  void setHabitName(String name) => _updateBuilder((b) => b.copyWith(habitName: name));

  /// Updates the reminder offset in the wizard state.
  void setReminderOffset(Duration offset) => _updateBuilder((b) => b.copyWith(reminderOffset: offset));

  /// Clears the reminder offset in the wizard state (no reminder after save).
  void clearReminderOffset() => _updateBuilder((b) => b.copyWith(clearReminderOffset: true));

  // ---------------------------------------------------------------------------
  // Wizard navigation
  // ---------------------------------------------------------------------------

  /// Syncs [PactCreationState.currentStep] to the given [PageView] page index.
  ///
  /// The edit wizard has 3 pages — indices 0, 1, 2 — mapped to
  /// [PactWizardStep.habitName], [PactWizardStep.reminder], and
  /// [PactWizardStep.summary] respectively. Out-of-range indices are clamped.
  ///
  /// A no-op when [wizardState] is null.
  void goToPage(int page) {
    final clamped = page.clamp(0, kEditSteps.length - 1);
    final targetStep = kEditSteps[clamped];
    unawaited(ref.read(crashlyticsServiceProvider).log('pact_edit: -> ${targetStep.name}'));
    unawaited(ref.read(logServiceProvider).info('pact_edit: -> ${targetStep.name}'));
    _updateWizardState((ws) => ws.copyWith(currentStep: targetStep));
  }

  /// Marks that the user tapped a summary row to jump back to a step.
  ///
  /// Sets [PactCreationState.usedSummaryJump] to `true` so the
  /// [PactEditSavedEvent] analytics event can report it. Idempotent.
  ///
  /// A no-op when [wizardState] is null.
  void markSummaryJumped() {
    _updateWizardState((ws) {
      if (ws.usedSummaryJump) return ws;
      return ws.copyWith(usedSummaryJump: true);
    });
  }

  // ---------------------------------------------------------------------------
  // save
  // ---------------------------------------------------------------------------

  /// Persists the edited pact, reschedules reminders, and fires analytics.
  ///
  /// Guard: returns immediately when [wizardState] or [originalPact] is null
  /// (i.e. when called before [load] completes).
  ///
  /// ## What changes
  ///
  /// Only [Pact.habitName] and [Pact.reminderOffset] are writable in the edit
  /// wizard. All other pact fields are preserved via [Pact.copyWith] from
  /// [originalPact].
  ///
  /// ## Reminders
  ///
  /// All existing reminder notifications are cancelled unconditionally. If the
  /// updated pact has a non-null reminder offset, reminders are rescheduled for
  /// the existing window of showups (fire-and-forget).
  ///
  /// ## Analytics
  ///
  /// Fires [PactEditSavedEvent] with boolean flags indicating which fields
  /// changed, the resulting reminder offset in minutes (or null if cleared),
  /// and whether the user jumped back to a step from the summary screen.
  Future<void> save() async {
    final wizardState = state.wizardState;
    final originalPact = state.originalPact;
    if (wizardState == null || originalPact == null) return;

    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      final newHabitName = wizardState.habitName.trim();
      final newReminderOffset = wizardState.reminderOffset;

      final habitNameChanged = newHabitName != originalPact.habitName;
      final reminderChanged = newReminderOffset != originalPact.reminderOffset;

      final updatedPact = originalPact.copyWith(
        habitName: newHabitName,
        reminderOffset: newReminderOffset,
        clearReminderOffset: newReminderOffset == null,
      );

      final pactService = ref.read(pactServiceProvider);
      await pactService.updatePact(updatedPact);

      // Cancel all pending reminder notifications — safe even when there was
      // no reminder configured before (no-op in that case).
      await ref.read(reminderSchedulingServiceProvider).cancelAllRemindersForPact(arg);

      // Reschedule only when the updated pact has a reminder offset.
      if (newReminderOffset != null) {
        final showups = await pactService.getShowupsForPact(arg);
        unawaited(
          ref.read(reminderSchedulingServiceProvider).scheduleRemindersForShowups(
                pact: updatedPact,
                showups: showups,
              ),
        );
      }

      // Log breadcrumb and fire analytics (fire-and-forget — no-throw contract).
      // PII rule: log only field lengths and change flags — no habit name or reason.
      unawaited(
        ref.read(logServiceProvider).info(
              'pact_edit_saved: id=$arg'
              ' habitNameChanged=$habitNameChanged'
              ' reminderChanged=$reminderChanged',
            ),
      );
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
              PactEditSavedEvent(
                pactId: originalPact.id,
                habitNameChanged: habitNameChanged,
                reminderChanged: reminderChanged,
                newReminderOffsetMinutes: newReminderOffset?.inMinutes,
                usedSummaryJump: wizardState.usedSummaryJump,
              ),
            ),
      );
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('pact_edit_save_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(saveError: e);
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

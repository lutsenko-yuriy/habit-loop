import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_builder.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';

// 3-page edit wizard step indices: 0 = habitName, 1 = reminder, 2 = summary.
// Platform pages import this to drive step indicators and PageController targets.
const List<PactWizardStep> kEditSteps = [
  PactWizardStep.habitName,
  PactWizardStep.reminder,
  PactWizardStep.summary,
];

const int kEditWizardPageCount = 3;

// Overridable in tests to keep the initial PactBuilder snapshot deterministic.
final pactEditTodayProvider = Provider<DateTime>((ref) => DateTime.now());

class PactEditWizardState {
  const PactEditWizardState({
    this.isLoading = false,
    this.loadError,
    this.wizardState,
    this.originalPact,
    this.isSaving = false,
    this.saveError,
  });

  final bool isLoading;
  final Object? loadError;
  // null until load completes.
  final PactCreationState? wizardState;
  // null until load completes; used in save to compute changed fields.
  final Pact? originalPact;
  final bool isSaving;
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

final pactEditViewModelProvider = NotifierProviderFamily<PactEditViewModel, PactEditWizardState, String>(
  PactEditViewModel.new,
);

// Updates only habitName and reminderOffset — all other pact fields are fixed post-creation.
class PactEditViewModel extends FamilyNotifier<PactEditWizardState, String> {
  @override
  PactEditWizardState build(String pactId) => const PactEditWizardState();

  // No-op before load completes — prevents crashes from UI callbacks on uninitialized state.
  void _updateWizardState(PactCreationState Function(PactCreationState) update) {
    final ws = state.wizardState;
    if (ws == null) return;
    state = state.copyWith(wizardState: update(ws));
  }

  void _updateBuilder(PactBuilder Function(PactBuilder) update) {
    _updateWizardState((ws) => ws.copyWith(builder: update(ws.builder)));
  }

  // Seeds wizardState from the pact repo; migrates legacy schedule types via PactBuilder.fromPact.
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

      // Track legacy schedule type for codec-drop telemetry (no PII — enum only).
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

  void setHabitName(String name) => _updateBuilder((b) => b.copyWith(habitName: name));
  void setReminderOffset(Duration offset) => _updateBuilder((b) => b.copyWith(reminderOffset: offset));
  void clearReminderOffset() => _updateBuilder((b) => b.copyWith(clearReminderOffset: true));

  // Clamps to valid range; no-op when wizardState is null.
  void goToPage(int page) {
    final clamped = page.clamp(0, kEditSteps.length - 1);
    final targetStep = kEditSteps[clamped];
    unawaited(ref.read(crashlyticsServiceProvider).log('pact_edit: -> ${targetStep.name}'));
    unawaited(ref.read(logServiceProvider).info('pact_edit: -> ${targetStep.name}'));
    _updateWizardState((ws) => ws.copyWith(currentStep: targetStep));
  }

  // Sets usedSummaryJump = true for analytics. Idempotent; no-op when wizardState is null.
  void markSummaryJumped() {
    _updateWizardState((ws) {
      if (ws.usedSummaryJump) return ws;
      return ws.copyWith(usedSummaryJump: true);
    });
  }

  // Guards on null wizardState/originalPact. PII rule: logs only change flags — no habit name.
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
      await pactService.updatePact(updatedPact, now: ref.read(pactEditTodayProvider));

      // Load showups once — deterministic cancellation (HAB-100) + rescheduling if offset set.
      final showups = await pactService.getShowupsForPact(arg);
      final showupIds = showups.map((s) => s.id).toList();

      await ref.read(reminderSchedulingServiceProvider).cancelAllRemindersForPact(arg, showupIds: showupIds);

      if (newReminderOffset != null) {
        unawaited(
          ref.read(reminderSchedulingServiceProvider).scheduleRemindersForShowups(
                pact: updatedPact,
                showups: showups,
              ),
        );
      }

      // PII rule: log only change flags — no habit name or reason.
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

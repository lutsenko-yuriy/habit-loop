import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

/// Provides the current time. Overridable in tests to make auto-fail logic
/// deterministic.
///
/// NOTE: This provider is intentionally NOT cached between navigations — it is
/// invalidated by [ShowupDetailScreen] before every [ShowupDetailViewModel.load]
/// call so that `DateTime.now()` is always sampled at the moment the screen
/// opens, not at app-start time.
final showupDetailNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Family provider keyed by showup ID.
///
/// Uses `autoDispose` so state is released when the screen is popped, avoiding
/// unbounded accumulation of one ViewModel instance per visited showup ID.
/// [ShowupDetailScreen.initState] always calls [ShowupDetailViewModel.load] on
/// entry, so re-creating the state on each visit is correct and safe.
final showupDetailViewModelProvider =
    AutoDisposeNotifierProviderFamily<ShowupDetailViewModel, ShowupDetailState, String>(ShowupDetailViewModel.new);

/// View model for the showup detail screen.
///
/// Keyed by showup ID (the [arg]).
///
/// Responsibilities:
/// - [load] fetches the showup, resolves the habit name from its pact,
///   and auto-fails a pending showup if the current time is past
///   `scheduledAt + duration`.
/// - [markDone] / [markFailed] update and persist the status; no-ops when
///   the showup is already resolved.
/// - [saveNote] persists a note regardless of showup status. An empty string
///   clears the note.
class ShowupDetailViewModel extends AutoDisposeFamilyNotifier<ShowupDetailState, String> {
  @override
  ShowupDetailState build(String showupId) {
    return const ShowupDetailState();
  }

  Future<void> load() async {
    // Clear any stale saving state from a previous visit so buttons are never
    // permanently disabled when the screen is re-entered after an interrupted save.
    state = state.copyWith(
      isLoading: true,
      clearLoadError: true,
      isSaving: false,
      clearMarkError: true,
      clearNoteError: true,
    );

    try {
      // Log screen breadcrumb for production diagnostics (fire-and-forget).
      // PII rule: only showup ID — no habit name or note content.
      unawaited(ref.read(crashlyticsServiceProvider).log('screen: showup_detail(id=$arg)'));
      unawaited(ref.read(logServiceProvider).info('showup_detail: load(id=$arg)'));

      final showupRepo = ref.read(showupRepositoryProvider);
      final pactRepo = ref.read(pactRepositoryProvider);

      var showup = await showupRepo.getShowupById(arg);
      if (showup == null) {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Showup not found: $arg'),
          isShowupNotFound: true,
        );
        return;
      }

      // Resolve habit name from the associated pact.
      // If the pact is missing (e.g. deleted while showups were not cleaned up),
      // habitName is left null so the UI layer can show a localised fallback.
      final pact = await pactRepo.getPactById(showup.pactId);
      final habitName = pact?.habitName;

      // Sample the clock once using showupDetailNowProvider (invalidated by
      // ShowupDetailScreen before load() is called so it always reflects the
      // real current time). Shared between the auto-fail check and the UI state
      // derivation so both are consistent.
      final now = ref.read(showupDetailNowProvider);

      // Auto-fail if the showup is still pending but the window has passed.
      bool wasAutoFailed = false;
      final pactStatsService = ref.read(pactStatsServiceProvider);
      if (showup.status == ShowupStatus.pending) {
        final endTime = showup.scheduledAt.add(showup.duration);
        if (now.isAfter(endTime)) {
          showup = await pactStatsService.persistShowupStatus(
            showup: showup,
            status: ShowupStatus.failed,
          );
          wasAutoFailed = true;

          // Fire auto-fail analytics and log (fire-and-forget).
          unawaited(
            ref.read(analyticsServiceProvider).logEvent(ShowupAutoFailedEvent(pactId: showup.pactId)),
          );
          unawaited(ref.read(logServiceProvider).info('showup_auto_failed: id=$arg pactId=${showup.pactId}'));
        }
      }

      // Derive the time-sensitive UI state using the same injectable clock so
      // the badge is consistent with the auto-fail outcome.
      final uiState = deriveShowupUiState(
        showup: showup,
        now: now,
        reminderOffset: pact?.reminderOffset,
      );

      state = state.copyWith(
        showup: showup,
        habitName: habitName,
        reminderOffset: pact?.reminderOffset,
        clearReminderOffset: pact?.reminderOffset == null,
        uiState: uiState,
        isLoading: false,
        wasAutoFailed: wasAutoFailed,
      );
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('showup_detail_load_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  /// Marks the showup as done. No-op if the showup is not [ShowupStatus.pending].
  Future<void> markDone() async {
    final showup = state.showup;
    if (showup == null || showup.status != ShowupStatus.pending) return;
    await _updateStatus(ShowupStatus.done);
  }

  /// Marks the showup as failed. No-op if the showup is not [ShowupStatus.pending].
  Future<void> markFailed() async {
    final showup = state.showup;
    if (showup == null || showup.status != ShowupStatus.pending) return;
    await _updateStatus(ShowupStatus.failed);
  }

  Future<void> _updateStatus(ShowupStatus newStatus) async {
    state = state.copyWith(isSaving: true, clearMarkError: true);

    final actionName = newStatus == ShowupStatus.done ? 'mark_done' : 'mark_failed';

    try {
      // Log action breadcrumb for production diagnostics (fire-and-forget).
      // PII rule: only showup ID and status enum — no habit name or note.
      unawaited(ref.read(crashlyticsServiceProvider).log('action: $actionName(showupId=$arg)'));
      unawaited(ref.read(logServiceProvider).info('showup_$actionName: id=$arg'));

      final updatedShowup = await ref.read(pactStatsServiceProvider).persistShowupStatus(
            showup: state.showup!,
            status: newStatus,
          );
      // Update uiState to reflect the new resolved status so the badge
      // updates immediately without requiring a screen reload.
      final resolvedUiState = switch (newStatus) {
        ShowupStatus.done => ShowupUiState.done,
        ShowupStatus.failed => ShowupUiState.failed,
        ShowupStatus.pending => state.uiState,
      };
      state = state.copyWith(showup: updatedShowup, uiState: resolvedUiState, isSaving: false);

      // Cancel the pending reminder and deadline notifications now that the
      // showup has been resolved. Routing through ReminderSchedulingService keeps
      // the cancellation path symmetric with the scheduling path.
      // The no-throw contract on NotificationService means this will never throw.
      unawaited(ref.read(reminderSchedulingServiceProvider).cancelRemindersForShowup(updatedShowup.id));
      unawaited(
        ref.read(crashlyticsServiceProvider).log(
              'ShowupDetailViewModel: cancelled notification for showup ${updatedShowup.id}',
            ),
      );

      // Determine the analytics event inside the try block so that a StateError
      // on an unexpected pending status is caught by the outer catch and
      // surfaced as markError rather than being swallowed.
      final AnalyticsEvent event = switch (newStatus) {
        ShowupStatus.done => ShowupMarkedDoneEvent(pactId: updatedShowup.pactId),
        ShowupStatus.failed => ShowupMarkedFailedEvent(pactId: updatedShowup.pactId),
        ShowupStatus.pending => throw StateError('Unexpected pending status'),
      };

      // Fire analytics for manual status changes (fire-and-forget).
      unawaited(ref.read(analyticsServiceProvider).logEvent(event));
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('showup_${actionName}_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isSaving: false, markError: e);
    }
  }

  /// Saves a note on the showup. An empty string clears the note.
  /// Always available regardless of showup status.
  Future<void> saveNote(String note) async {
    final showup = state.showup;
    if (showup == null) return;
    state = state.copyWith(isSaving: true, clearNoteError: true);
    try {
      final updatedShowup = note.isEmpty ? showup.copyWith(clearNote: true) : showup.copyWith(note: note);
      await ref.read(showupRepositoryProvider).updateShowup(updatedShowup);
      state = state.copyWith(showup: updatedShowup, isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, noteError: e);
    }
  }
}

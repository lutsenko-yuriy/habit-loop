import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/showup/tail_zone.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

// Overridable in tests; invalidated before each load so DateTime.now() is sampled at screen-open time.
final showupDetailNowProvider = Provider<DateTime>((ref) => DateTime.now());

// autoDispose releases state when the screen is popped.
final showupDetailViewModelProvider =
    AutoDisposeNotifierProviderFamily<ShowupDetailViewModel, ShowupDetailState, String>(ShowupDetailViewModel.new);

class ShowupDetailViewModel extends AutoDisposeFamilyNotifier<ShowupDetailState, String> {
  @override
  ShowupDetailState build(String showupId) {
    // ignore: avoid_print
    print('DIAG ShowupDetailViewModel.build($showupId) at ${DateTime.now().toIso8601String()}');
    return const ShowupDetailState();
  }

  Future<void> load() async {
    // Clear stale save state from a previous visit so buttons are never permanently disabled.
    state = state.copyWith(
      isLoading: true,
      clearLoadError: true,
      isSaving: false,
      clearMarkError: true,
      clearNoteError: true,
    );

    try {
      // PII rule: only showup ID — no habit name or note content.
      unawaited(ref.read(crashlyticsServiceProvider).log('screen: showup_detail(id=$arg)'));
      unawaited(ref.read(logServiceProvider).info('showup_detail: load(id=$arg)'));

      final showupService = ref.read(showupServiceProvider);

      var showup = await showupService.getShowupById(arg);
      if (showup == null) {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Showup not found: $arg'),
          isShowupNotFound: true,
        );
        return;
      }

      final pact = await showupService.getPactById(showup.pactId);
      final habitName = pact?.habitName;

      final now = ref.read(showupDetailNowProvider);

      bool wasAutoFailed = false;
      final pactStatsService = ref.read(pactStatsServiceProvider);
      if (showup.status == ShowupStatus.pending) {
        final endTime = showup.scheduledAt.add(showup.duration);
        if (now.isAfter(endTime)) {
          showup = await pactStatsService.persistShowupStatus(
            showup: showup,
            status: ShowupStatus.failed,
            now: now,
          );
          wasAutoFailed = true;

          unawaited(
            ref.read(analyticsServiceProvider).logEvent(ShowupAutoFailedEvent(pactId: showup.pactId)),
          );
          unawaited(ref.read(logServiceProvider).info('showup_auto_failed: id=$arg pactId=${showup.pactId}'));
        }
      }

      final uiState = deriveShowupUiState(
        showup: showup,
        now: now,
        reminderOffset: pact?.reminderOffset,
      );

      final rc = ref.read(remoteConfigServiceProvider);
      final tailDays = rc.getInt('pact_timeline_no_grouping_tail_period_in_days');
      final canRedeem = showup.status == ShowupStatus.failed &&
          showup.redeemable &&
          ref.read(featureFlagsProvider).showupRedemptionEnabled &&
          TailZone.contains(scheduledAt: showup.scheduledAt, now: now, days: tailDays);

      if (canRedeem && (showup.note?.isEmpty ?? true)) {
        unawaited(
          ref.read(analyticsServiceProvider).logEvent(ShowupRedemptionBlockedEvent(pactId: showup.pactId)),
        );
      }

      state = state.copyWith(
        showup: showup,
        habitName: habitName,
        reminderOffset: pact?.reminderOffset,
        clearReminderOffset: pact?.reminderOffset == null,
        uiState: uiState,
        isLoading: false,
        wasAutoFailed: wasAutoFailed,
        canRedeem: canRedeem,
      );
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('showup_detail_load_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  // No-op when showup is not pending.
  Future<void> markDone() async {
    final showup = state.showup;
    if (showup == null || showup.status != ShowupStatus.pending) return;
    await _updateStatus(ShowupStatus.done);
  }

  // No-op when showup is not pending.
  Future<void> markFailed() async {
    final showup = state.showup;
    if (showup == null || showup.status != ShowupStatus.pending) return;
    await _updateStatus(ShowupStatus.failed);
  }

  Future<void> _updateStatus(ShowupStatus newStatus) async {
    state = state.copyWith(isSaving: true, clearMarkError: true);

    final actionName = newStatus == ShowupStatus.done ? 'mark_done' : 'mark_failed';

    try {
      // PII rule: only showup ID and status enum — no habit name or note.
      unawaited(ref.read(crashlyticsServiceProvider).log('action: $actionName(showupId=$arg)'));
      unawaited(ref.read(logServiceProvider).info('showup_$actionName: id=$arg'));

      final updatedShowup = await ref.read(pactStatsServiceProvider).persistShowupStatus(
            showup: state.showup!,
            status: newStatus,
            // Manual fail makes the showup non-redeemable — user chose to fail.
            redeemable: newStatus == ShowupStatus.failed ? false : null,
            now: ref.read(showupDetailNowProvider),
          );
      final resolvedUiState = switch (newStatus) {
        ShowupStatus.done => ShowupUiState.done,
        ShowupStatus.failed => ShowupUiState.failed,
        ShowupStatus.pending => state.uiState,
      };
      state = state.copyWith(showup: updatedShowup, uiState: resolvedUiState, isSaving: false);

      // NotificationService is no-throw — cancellation never throws.
      unawaited(ref.read(reminderSchedulingServiceProvider).cancelRemindersForShowup(updatedShowup.id));
      unawaited(
        ref.read(crashlyticsServiceProvider).log(
              'ShowupDetailViewModel: cancelled notification for showup ${updatedShowup.id}',
            ),
      );

      final AnalyticsEvent event = switch (newStatus) {
        ShowupStatus.done => ShowupMarkedDoneEvent(pactId: updatedShowup.pactId),
        ShowupStatus.failed => ShowupMarkedFailedEvent(pactId: updatedShowup.pactId),
        ShowupStatus.pending => throw StateError('Unexpected pending status'),
      };

      unawaited(ref.read(analyticsServiceProvider).logEvent(event));
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('showup_${actionName}_failed: id=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isSaving: false, markError: e);
    }
  }

  // No-op when canRedeem is false, isSaving, or note is empty (note gate uses persisted note).
  Future<void> redeemShowup() async {
    final showup = state.showup;
    if (showup == null || !state.canRedeem || state.isSaving) return;

    final note = showup.note;
    if (note == null || note.isEmpty) {
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(ShowupRedemptionBlockedEvent(pactId: showup.pactId)),
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearMarkError: true);
    try {
      final updatedShowup = await ref.read(pactStatsServiceProvider).persistShowupStatus(
            showup: showup,
            status: ShowupStatus.done,
            now: ref.read(showupDetailNowProvider),
          );
      state = state.copyWith(
          showup: updatedShowup, uiState: ShowupUiState.done, isSaving: false, canRedeem: false, wasAutoFailed: false);

      final now = ref.read(showupDetailNowProvider);
      final today = DateTime(now.year, now.month, now.day);
      final scheduled = DateTime(showup.scheduledAt.year, showup.scheduledAt.month, showup.scheduledAt.day);
      final daysSince = today.difference(scheduled).inDays;

      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
              ShowupRedeemedEvent(
                pactId: showup.pactId,
                noteLength: note.length,
                daysSinceScheduled: daysSince,
              ),
            ),
      );
    } catch (e, st) {
      unawaited(ref.read(logServiceProvider).error('showup_redeem_failed: id=$arg', exception: e, stackTrace: st));
      state = state.copyWith(isSaving: false, markError: e);
    }
  }

  // Empty string clears the note. Always available regardless of showup status.
  Future<void> saveNote(String note) async {
    final showup = state.showup;
    if (showup == null) return;
    state = state.copyWith(isSaving: true, clearNoteError: true);
    try {
      final updatedShowup = note.isEmpty ? showup.copyWith(clearNote: true) : showup.copyWith(note: note);
      await ref.read(showupServiceProvider).updateShowup(updatedShowup);
      state = state.copyWith(showup: updatedShowup, isSaving: false);
      // Write-through: a note edit doesn't change stats, so refresh only the
      // cache directly — going through PactStatsService.persistStats would
      // redundantly rewrite Pact.stats and re-upload the pact to Firestore for
      // an edit that never changes stats. The cache's cached timelinePage must
      // still reflect the new note so Timeline shows it without an app
      // restart (HAB-174).
      final cache = ref.read(pactDetailCacheProvider);
      cache.evict(updatedShowup.pactId);
      await cache.load(updatedShowup.pactId, now: ref.read(showupDetailNowProvider));
    } catch (e) {
      state = state.copyWith(isSaving: false, noteError: e);
    }
  }
}

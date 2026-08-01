import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_bundle.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';

// Overridable in tests to make daysActive computation in stopPact deterministic.
final pactDetailNowProvider = Provider<DateTime>((ref) => DateTime.now());

final pactDetailViewModelProvider = NotifierProviderFamily<PactDetailViewModel, PactDetailState, String>(
  PactDetailViewModel.new,
);

class PactDetailViewModel extends FamilyNotifier<PactDetailState, String> {
  @override
  PactDetailState build(String pactId) {
    return const PactDetailState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearLoadError: true);

    try {
      // PII rule: only pact ID — no habit name.
      unawaited(ref.read(crashlyticsServiceProvider).log('screen: pact_detail(id=$arg)'));
      unawaited(ref.read(logServiceProvider).info('pact_detail: load(id=$arg)'));

      final pactService = ref.read(pactServiceProvider);
      final now = ref.read(pactDetailNowProvider);

      final PactDetailBundle bundle;
      try {
        bundle = await ref.read(pactDetailCacheProvider).load(arg, now: now);
      } on ArgumentError {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Pact not found: $arg'),
        );
        return;
      }

      var pact = bundle.pact;
      var stats = bundle.stats;

      // Uses showupsRemaining (from countTotal) not pending count — lazy generation
      // would fire prematurely after only the first window is resolved.
      if (pact.status == PactStatus.active) {
        final todayDate = DateTime(now.year, now.month, now.day);
        final endDateOnly = DateTime(pact.endDate.year, pact.endDate.month, pact.endDate.day);
        final daysLeft = endDateOnly.difference(todayDate).inDays;
        if (daysLeft <= 0 || stats.showupsRemaining == 0) {
          pact = pact.copyWith(
            status: PactStatus.completed,
            stats: stats.copyWith(
              startDate: pact.startDate,
              endDate: pact.endDate,
            ),
          );
          // updatePact write-throughs to PactDetailCache, reusing the showups
          // this load() call already fetched — no extra DB round-trip.
          await pactService.updatePact(pact, now: now);
          stats = pact.stats!;
        }
      }

      // Only one unresolved break can exist per pact at a time (HAB-195),
      // enforced by PactBreakService.startBreak — find it from the bundle
      // already loaded above rather than a separate repository round-trip.
      PactBreak? activeBreak;
      for (final b in bundle.breaks) {
        if (!b.isResolved(now)) {
          activeBreak = b;
          break;
        }
      }

      // Chain links (HAB-202) — cheap, uncached reads; a pact has at most one
      // predecessor and one successor.
      final predecessorPactId = pact.predecessorPactId;
      final predecessorPact = predecessorPactId == null ? null : await pactService.getPact(predecessorPactId);
      final successorPact = await pactService.getSuccessor(pact.id);

      // Cache-warm the neighbor bundles (HAB-206 WU2) so a subsequent
      // chain-link swap hits a warm PactDetailCache instead of a fresh DB
      // round trip. Fire-and-forget — must not delay this pact's own load.
      final cache = ref.read(pactDetailCacheProvider);
      if (predecessorPactId != null) {
        unawaited(cache.load(predecessorPactId, now: now));
      }
      if (successorPact != null) {
        unawaited(cache.load(successorPact.id, now: now));
      }

      state = state.copyWith(
        pact: pact,
        stats: stats,
        isLoading: false,
        activeBreak: activeBreak,
        clearActiveBreak: activeBreak == null,
        // Display-only: the banner must wait until the break actually
        // starts, unlike activeBreak's own "unresolved" gating (HAB-201).
        isBreakActiveNow: activeBreak != null && activeBreak.isActiveAt(now),
        predecessorPact: predecessorPact,
        clearPredecessorPact: predecessorPact == null,
        successorPact: successorPact,
        clearSuccessorPact: successorPact == null,
      );
    } catch (e, st) {
      unawaited(ref.read(logServiceProvider).error('pact_detail_load_failed: id=$arg', exception: e, stackTrace: st));
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  Future<void> stopPact(String? reason) async {
    final pact = state.pact;
    if (pact == null) return;
    state = state.copyWith(isStopping: true, clearStopError: true);
    try {
      // Load IDs before stop deletes them — deterministic cancellation (HAB-100).
      final showupIds = (await ref.read(pactServiceProvider).getShowupsForPact(arg)).map((s) => s.id).toList();

      final now = ref.read(pactDetailNowProvider);
      final updated = await ref.read(pactStatsServiceProvider).stopPact(
            pact: pact,
            pactId: arg,
            now: now,
            reason: reason,
            existingStats: state.stats,
          );
      final stats = updated.stats!;

      // Resolve any active break too — stopping the pact must not leave a
      // dangling break banner (HAB-208).
      final activeBreak = state.activeBreak;
      if (activeBreak != null) {
        await ref.read(pactBreakServiceProvider).stopBreak(activeBreak.id, now: now);
      }

      state = state.copyWith(
        pact: updated,
        stats: stats,
        isStopping: false,
        clearActiveBreak: true,
        isBreakActiveNow: false,
      );

      unawaited(ref.read(reminderSchedulingServiceProvider).cancelAllRemindersForPact(arg, showupIds: showupIds));
      unawaited(
        ref.read(crashlyticsServiceProvider).log(
              'PactDetailViewModel: cancelled all notifications for pact $arg',
            ),
      );

      // PII rule: log only counts and IDs — no habit name or stop reason.
      unawaited(
        ref.read(crashlyticsServiceProvider).log(
              'pact_stopped: id=$arg'
              ' done=${stats.showupsDone}'
              ' failed=${stats.showupsFailed}'
              ' remaining=${stats.showupsRemaining}',
            ),
      );
      unawaited(
        ref.read(logServiceProvider).info(
              'pact_stopped: id=$arg done=${stats.showupsDone}'
              ' failed=${stats.showupsFailed} remaining=${stats.showupsRemaining}',
            ),
      );
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(PactStoppedEvent(
              daysActive: now.difference(pact.startDate).inDays,
              totalShowupsDone: stats.showupsDone,
              totalShowupsFailed: stats.showupsFailed,
              totalShowupsRemaining: stats.showupsRemaining,
            )),
      );
    } catch (e, st) {
      unawaited(ref.read(logServiceProvider).error('pact_stop_failed: id=$arg', exception: e, stackTrace: st));
      state = state.copyWith(isStopping: false, stopError: e);
    }
  }

  /// Stops ("Resume pact") the pact's active break (HAB-195 WU5.2). No-op if
  /// there is no active break loaded in state.
  Future<void> stopBreak() async {
    final activeBreak = state.activeBreak;
    if (activeBreak == null) return;

    state = state.copyWith(isStoppingBreak: true, clearStopBreakError: true);
    try {
      final now = ref.read(pactDetailNowProvider);
      await ref.read(pactBreakServiceProvider).stopBreak(activeBreak.id, now: now);
      state = state.copyWith(isStoppingBreak: false, clearActiveBreak: true, isBreakActiveNow: false);

      // PII rule: only pact ID — no rationale.
      unawaited(ref.read(crashlyticsServiceProvider).log('pact_break_stopped: pactId=$arg'));
      unawaited(ref.read(logServiceProvider).info('pact_break_stopped: pactId=$arg'));
      // A break's startDate can be future-dated (not yet begun) — clamp so
      // this never reports negative, matching the event's documented
      // contract of "days the break had been active".
      final daysSinceStart = now.difference(activeBreak.startDate).inDays;
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(PactBreakStoppedEvent(
              pactId: arg,
              originalEndType: activeBreak.plannedEndDate == null ? 'until_pact_ends' : 'fixed_date',
              daysSinceStart: daysSinceStart < 0 ? 0 : daysSinceStart,
            )),
      );
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('pact_break_stop_failed: pactId=$arg', exception: e, stackTrace: st),
      );
      state = state.copyWith(isStoppingBreak: false, stopBreakError: e);
    }
  }

  Future<void> archivePact(bool archive, {required String source}) async {
    final pact = state.pact;
    if (pact == null) return;
    state = state.copyWith(isArchiving: true, clearArchiveError: true);
    try {
      await ref.read(pactServiceProvider).archivePact(arg, archive);
      final updated = pact.copyWith(archived: archive);
      state = state.copyWith(pact: updated, isArchiving: false);
      final statusStr = pact.status == PactStatus.completed ? 'completed' : 'stopped';
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
              archive
                  ? PactArchivedEvent(pactId: arg, pactStatus: statusStr, source: source)
                  : PactUnarchivedEvent(pactId: arg, pactStatus: statusStr, source: source),
            ),
      );
    } catch (e, st) {
      unawaited(ref.read(logServiceProvider).error('pact_archive_failed: id=$arg', exception: e, stackTrace: st));
      state = state.copyWith(isArchiving: false, archiveError: e);
    }
  }

  Future<void> saveNote(String note) async {
    final pact = state.pact;
    if (pact == null) return;

    final wasEdit = pact.stopReason != null && pact.stopReason!.isNotEmpty;
    state = state.copyWith(isSavingNote: true, clearNoteError: true);
    try {
      final updated = note.isEmpty ? pact.copyWith(clearStopReason: true) : pact.copyWith(stopReason: note);
      await ref.read(pactServiceProvider).updatePact(updated, now: ref.read(pactDetailNowProvider));
      state = state.copyWith(pact: updated, isSavingNote: false);

      unawaited(
        ref.read(analyticsServiceProvider).logEvent(PactNoteSavedEvent(
              pactId: arg,
              pactStatus: pact.status == PactStatus.completed ? 'completed' : 'stopped',
              noteLength: note.length,
              wasEdit: wasEdit,
            )),
      );
    } catch (e, st) {
      unawaited(ref.read(logServiceProvider).error('pact_save_note_failed: id=$arg', exception: e, stackTrace: st));
      state = state.copyWith(isSavingNote: false, noteError: e);
    }
  }
}

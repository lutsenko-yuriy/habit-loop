import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_bundle.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
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
      final cache = ref.read(pactDetailCacheProvider);

      final PactDetailBundle bundle;
      try {
        bundle = await cache.load(arg, now: now);
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

      // Chain links (HAB-202) — a pact has at most one predecessor and one
      // successor. Checked against PactDetailCache's identity index first
      // (HAB-206 WU3) — cache.load() above, and any earlier neighbor
      // resolution, already populates it, so a pact reached via chain-link
      // navigation usually already knows its own neighbors without a DB
      // round trip. This — not just the bundle prefetch below — is what
      // keeps the swap free of a loading-spinner blink.
      final predecessorPactId = pact.predecessorPactId;
      Pact? predecessorPact;
      if (predecessorPactId != null) {
        predecessorPact = cache.peekPact(predecessorPactId) ?? await pactService.getPact(predecessorPactId);
        if (predecessorPact != null) cache.rememberPact(predecessorPact);
      }
      final successorPact = cache.peekSuccessor(pact.id) ?? await pactService.getSuccessor(pact.id);
      if (successorPact != null) cache.rememberPact(successorPact);

      // Cache-warm the neighbor bundles (HAB-206 WU2) so a subsequent
      // chain-link swap hits a warm PactDetailCache instead of a fresh DB
      // round trip. Fire-and-forget — must not delay this pact's own load.
      // Swallows ArgumentError (neighbor deleted/concurrently modified
      // mid-warm) so it can't surface as a fatal Crashlytics report via the
      // global error handler — the swap itself will re-surface a real "not
      // found" if the user actually navigates there.
      //
      // Also warms one hop further than the bundle prefetch reaches (HAB-206
      // WU3) — identity only (which Pact it is, not its full bundle), so it
      // stays well short of "loading a next-next pact" — just enough that
      // *its* neighbor resolution above also hits the identity index instead
      // of a fresh DB round trip once the user actually navigates there.
      if (predecessorPact != null) {
        unawaited(_warmChainCache(cache, predecessorPact.id, now));
        final grandPredecessorId = predecessorPact.predecessorPactId;
        if (grandPredecessorId != null && cache.peekPact(grandPredecessorId) == null) {
          unawaited(_warmChainIdentity(cache, () => pactService.getPact(grandPredecessorId)));
        }
      }
      if (successorPact != null) {
        unawaited(_warmChainCache(cache, successorPact.id, now));
        if (cache.peekSuccessor(successorPact.id) == null) {
          unawaited(_warmChainIdentity(cache, () => pactService.getSuccessor(successorPact.id)));
        }
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

  // Best-effort — this is unawaited by every caller, so any exception here
  // (ArgumentError for a deleted neighbor, or a transient DB read failure)
  // must be swallowed rather than escaping to the global error handler,
  // which would record a harmless background warm as a fatal crash.
  Future<void> _warmChainCache(PactDetailCache cache, String pactId, DateTime now) async {
    try {
      await cache.load(pactId, now: now);
    } catch (e, st) {
      unawaited(
        ref
            .read(logServiceProvider)
            .error('pact_detail_chain_cache_warm_failed: id=$pactId', exception: e, stackTrace: st),
      );
    }
  }

  // Same fire-and-forget/error-swallowing contract as _warmChainCache, but
  // resolves and remembers a bare Pact identity (HAB-206 WU3) rather than a
  // full bundle — used to warm one hop further than the bundle prefetch
  // reaches, so PactDetailCache.peekPact/peekSuccessor can answer without a
  // DB round trip the moment the user actually navigates that far.
  Future<void> _warmChainIdentity(PactDetailCache cache, Future<Pact?> Function() resolve) async {
    try {
      final resolved = await resolve();
      if (resolved != null) cache.rememberPact(resolved);
    } catch (e, st) {
      unawaited(
        ref.read(logServiceProvider).error('pact_detail_chain_identity_warm_failed', exception: e, stackTrace: st),
      );
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

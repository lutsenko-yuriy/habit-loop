import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          await pactService.updatePact(pact);
          stats = pact.stats!;
        }
      }

      state = state.copyWith(pact: pact, stats: stats, isLoading: false);
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
      state = state.copyWith(pact: updated, stats: stats, isStopping: false);

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
      await ref.read(pactServiceProvider).updatePact(updated);
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

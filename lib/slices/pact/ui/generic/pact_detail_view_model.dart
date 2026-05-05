import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/infrastructure/crashlytics/providers/crashlytics_providers.dart';
import 'package:habit_loop/infrastructure/logging/providers/log_service_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';

/// Provides the current time for pact detail operations.
///
/// Overridable in tests to make [PactDetailViewModel.stopPact] (specifically
/// the `daysActive` computation in the analytics event) deterministic.
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
      // Log screen breadcrumb for production diagnostics (fire-and-forget).
      // PII rule: only pact ID — no habit name.
      unawaited(ref.read(crashlyticsServiceProvider).log('screen: pact_detail(id=$arg)'));
      unawaited(ref.read(logServiceProvider).info('pact_detail: load(id=$arg)'));

      final pactService = ref.read(pactServiceProvider);
      final pactStatsService = ref.read(pactStatsServiceProvider);

      var pact = await pactService.getPact(arg);
      if (pact == null) {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Pact not found: $arg'),
        );
        return;
      }

      // Load showups directly from the stats service (which owns the showup repository).
      // Note: showup reads for stats computation go through PactStatsService.
      final showups = await pactStatsService.loadShowupsForPact(arg);
      var stats = pactStatsService.currentStats(pact: pact, showups: showups);

      // Auto-complete the pact when its end date has passed or all showups
      // across the entire schedule have been resolved (showupsRemaining == 0).
      // Using stats.showupsRemaining (derived from countTotal - done - failed)
      // rather than the pending count in the persisted window ensures that, with
      // lazy generation, we do not fire prematurely after only the first window
      // is resolved.
      if (pact.status == PactStatus.active) {
        final today = ref.read(pactDetailNowProvider);
        final todayDate = DateTime(today.year, today.month, today.day);
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

      // Log breadcrumb and fire analytics for pact stop (fire-and-forget).
      // CrashlyticsService, AnalyticsService, and LogService are no-throw.
      // PII rule: log only counts and IDs — no habit name, no stop reason.
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
}

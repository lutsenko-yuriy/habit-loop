import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';

/// Provides the current time for pact detail operations.
///
/// Overridable in tests to make [PactDetailViewModel.stopPact] (specifically
/// the `daysActive` computation in the analytics event) deterministic.
final pactDetailNowProvider = Provider<DateTime>((ref) => DateTime.now());

final pactDetailRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('Override pactDetailRepositoryProvider');
});

final pactDetailShowupRepositoryProvider = Provider<ShowupRepository>((ref) {
  throw UnimplementedError('Override pactDetailShowupRepositoryProvider');
});

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
      final pactRepo = ref.read(pactDetailRepositoryProvider);
      final showupRepo = ref.read(pactDetailShowupRepositoryProvider);
      final pactStatsService = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
      );
      var pact = await pactRepo.getPactById(arg);
      if (pact == null) {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Pact not found: $arg'),
        );
        return;
      }
      final showups = await showupRepo.getShowupsForPact(arg);
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
          await pactRepo.updatePact(pact);
          stats = pact.stats!;
        }
      }

      state = state.copyWith(pact: pact, stats: stats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  Future<void> stopPact(String? reason) async {
    final pact = state.pact;
    if (pact == null) return;
    state = state.copyWith(isStopping: true, clearStopError: true);
    try {
      final now = ref.read(pactDetailNowProvider);
      final updated = await PactStatsService(
        pactRepository: ref.read(pactDetailRepositoryProvider),
        showupRepository: ref.read(pactDetailShowupRepositoryProvider),
      ).stopPact(
        pact: pact,
        pactId: arg,
        now: now,
        reason: reason,
        existingStats: state.stats,
      );
      final stats = updated.stats!;
      state = state.copyWith(pact: updated, stats: stats, isStopping: false);

      // Fire analytics for pact stop.
      // AnalyticsService is no-throw; no wrapping try/catch needed.
      await ref.read(analyticsServiceProvider).logEvent(PactStoppedEvent(
            daysActive: now.difference(pact.startDate).inDays,
            totalShowupsDone: stats.showupsDone,
            totalShowupsFailed: stats.showupsFailed,
            totalShowupsRemaining: stats.showupsRemaining,
          ));
    } catch (e) {
      state = state.copyWith(isStopping: false, stopError: e);
    }
  }
}

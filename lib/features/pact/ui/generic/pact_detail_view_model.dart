import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/features/pact/analytics/pact_analytics_events.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact_detail_state.dart';
import 'package:habit_loop/features/pact/domain/pact_stats.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';

final pactDetailRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('Override pactDetailRepositoryProvider');
});

final pactDetailShowupRepositoryProvider = Provider<ShowupRepository>((ref) {
  throw UnimplementedError('Override pactDetailShowupRepositoryProvider');
});

final pactDetailViewModelProvider = NotifierProviderFamily<
    PactDetailViewModel, PactDetailState, String>(
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
      var pact = await pactRepo.getPactById(arg);
      if (pact == null) {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Pact not found: $arg'),
        );
        return;
      }
      final showups = await showupRepo.getShowupsForPact(arg);
      final totalShowups = ShowupGenerator.countTotal(pact);
      var stats = PactStats.compute(
        pact: pact,
        showups: showups,
        totalShowups: totalShowups,
      );

      // Auto-complete the pact when its end date has passed or all showups
      // across the entire schedule have been resolved (showupsRemaining == 0).
      // Using stats.showupsRemaining (derived from countTotal - done - failed)
      // rather than the pending count in the persisted window ensures that, with
      // lazy generation, we do not fire prematurely after only the first window
      // is resolved.
      if (pact.status == PactStatus.active) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final endDateOnly = DateTime(pact.endDate.year, pact.endDate.month, pact.endDate.day);
        final daysLeft = endDateOnly.difference(todayDate).inDays;
        if (daysLeft <= 0 || stats.showupsRemaining == 0) {
          pact = pact.copyWith(status: PactStatus.completed);
          await pactRepo.updatePact(pact);
          stats = PactStats.compute(
            pact: pact,
            showups: showups,
            totalShowups: totalShowups,
          );
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
      final now = DateTime.now();
      final updated = pact.copyWith(
        status: PactStatus.stopped,
        endDate: DateTime(now.year, now.month, now.day),
        stopReason: reason,
        clearStopReason: reason == null || reason.trim().isEmpty,
      );
      await ref.read(pactDetailRepositoryProvider).updatePact(updated);
      final showups = await ref.read(pactDetailShowupRepositoryProvider).getShowupsForPact(arg);
      final stats = PactStats.compute(
        pact: updated,
        showups: showups,
        totalShowups: ShowupGenerator.countTotal(updated),
      );
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

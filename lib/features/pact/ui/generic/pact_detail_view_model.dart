import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact_detail_state.dart';
import 'package:habit_loop/features/pact/domain/pact_stats.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';

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
      final pact = await pactRepo.getPactById(arg);
      if (pact == null) {
        state = state.copyWith(
          isLoading: false,
          loadError: StateError('Pact not found: $arg'),
        );
        return;
      }
      final showups = await showupRepo.getShowupsForPact(arg);
      final stats = PactStats.compute(pact: pact, showups: showups);
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
      final updated = pact.copyWith(
        status: PactStatus.stopped,
        stopReason: reason,
        clearStopReason: reason == null || reason.trim().isEmpty,
      );
      await ref.read(pactDetailRepositoryProvider).updatePact(updated);
      state = state.copyWith(pact: updated, isStopping: false);
    } catch (e) {
      state = state.copyWith(isStopping: false, stopError: e);
    }
  }
}

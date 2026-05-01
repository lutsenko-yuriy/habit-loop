import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';

final pactListRepositoryProvider = Provider<PactRepository>(
  (_) => throw UnimplementedError('Override pactListRepositoryProvider'),
);

final pactListShowupRepositoryProvider = Provider<ShowupRepository>(
  (_) => throw UnimplementedError('Override pactListShowupRepositoryProvider'),
);

final pactListViewModelProvider = NotifierProvider<PactListViewModel, PactListState>(PactListViewModel.new);

class PactListViewModel extends Notifier<PactListState> {
  @override
  PactListState build() => const PactListState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final pactRepo = ref.read(pactListRepositoryProvider);
      final showupRepo = ref.read(pactListShowupRepositoryProvider);
      final pacts = await pactRepo.getAllPacts();
      final now = DateTime.now();

      final entries = <PactListEntry>[];
      for (final pact in pacts) {
        DateTime? nextShowupAt;
        if (pact.status == PactStatus.active) {
          final showups = await showupRepo.getShowupsForPact(pact.id);
          final pending = showups.where((s) => s.status == ShowupStatus.pending && s.scheduledAt.isAfter(now)).toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          if (pending.isNotEmpty) nextShowupAt = pending.first.scheduledAt;
        }
        entries.add(PactListEntry(pact: pact, nextShowupAt: nextShowupAt));
      }

      entries.sort((a, b) {
        final statusCmp = _statusOrder(a.pact.status).compareTo(_statusOrder(b.pact.status));
        if (statusCmp != 0) return statusCmp;
        if (a.pact.status == PactStatus.active) {
          final aT = a.nextShowupAt ?? DateTime(9999);
          final bT = b.nextShowupAt ?? DateTime(9999);
          return aT.compareTo(bT);
        }
        return a.pact.endDate.compareTo(b.pact.endDate);
      });

      state = state.copyWith(entries: entries, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void toggleFilter(PactStatus status) {
    final current = state.activeFilters;
    final next = Set<PactStatus>.of(current);
    if (current.contains(status)) {
      next.remove(status);
    } else {
      next.add(status);
    }
    state = state.copyWith(activeFilters: next);
  }

  int _statusOrder(PactStatus s) => switch (s) {
        PactStatus.active => 0,
        PactStatus.completed => 1,
        PactStatus.stopped => 2,
      };
}

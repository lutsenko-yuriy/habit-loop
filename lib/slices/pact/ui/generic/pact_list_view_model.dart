import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_state.dart';

final pactListViewModelProvider = NotifierProvider<PactListViewModel, PactListState>(PactListViewModel.new);

class PactListViewModel extends Notifier<PactListState> {
  /// True while a [load] call is already awaiting completion.
  ///
  /// Guards against overlapping calls (e.g. initState and a navigation-return
  /// both triggering load simultaneously) which would execute redundant DB
  /// round-trips and potentially emit inconsistent intermediate states.
  bool _loadInProgress = false;

  @override
  PactListState build() => const PactListState();

  Future<void> load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      await _loadInner();
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _loadInner() async {
    state = state.copyWith(isLoading: true);
    try {
      final queryService = ref.read(pactListQueryServiceProvider);
      final pacts = await queryService.getAllPacts();
      final now = DateTime.now();

      final entries = <PactListEntry>[];
      for (final pact in pacts) {
        DateTime? nextShowupAt;
        if (pact.status == PactStatus.active) {
          final showups = await queryService.getShowupsForPact(pact.id);
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

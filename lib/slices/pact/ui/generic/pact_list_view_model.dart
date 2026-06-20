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
        final groupCmp =
            _sortOrder(a.pact.archived, a.pact.status).compareTo(_sortOrder(b.pact.archived, b.pact.status));
        if (groupCmp != 0) return groupCmp;
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

  void toggleArchived() {
    state = state.copyWith(showArchived: !state.showArchived);
  }

  int _sortOrder(bool isArchived, PactStatus s) => switch ((isArchived, s)) {
        (false, PactStatus.active) => 0,
        (false, PactStatus.completed) => 1,
        (false, PactStatus.stopped) => 2,
        (true, PactStatus.completed) => 3,
        (true, PactStatus.stopped) => 4,
        _ => 5,
      };
}

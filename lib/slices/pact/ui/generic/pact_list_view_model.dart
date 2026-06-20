import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/analytics/pact_analytics_events.dart';
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

  Future<void> archivePact(String pactId, bool archived, {String source = 'pact_list_swipe'}) async {
    final entry = state.entries.where((e) => e.pact.id == pactId).firstOrNull;
    if (entry == null) return;

    // Optimistic update — reflect the change in the UI immediately.
    final optimistic = _withArchived(state, pactId, archived);
    state = optimistic;

    try {
      await ref.read(pactServiceProvider).archivePact(pactId, archived);
      final statusStr = entry.pact.status == PactStatus.completed ? 'completed' : 'stopped';
      unawaited(ref.read(analyticsServiceProvider).logEvent(
            archived
                ? PactArchivedEvent(pactId: pactId, pactStatus: statusStr, source: source)
                : PactUnarchivedEvent(pactId: pactId, pactStatus: statusStr, source: source),
          ));
    } catch (_) {
      // Revert to the pre-optimistic state on failure.
      state = _withArchived(optimistic, pactId, !archived);
    }
  }

  /// Returns a copy of [base] with the pact [pactId] marked [archived] and
  /// re-sorted. [showArchived] is intentionally left unchanged — the user
  /// controls section visibility; archiving alone does not expand it.
  PactListState _withArchived(PactListState base, String pactId, bool archived) {
    final updated = base.entries.map((e) {
      if (e.pact.id != pactId) return e;
      return PactListEntry(pact: e.pact.copyWith(archived: archived), nextShowupAt: e.nextShowupAt);
    }).toList()
      ..sort((a, b) {
        final cmp = _sortOrder(a.pact.archived, a.pact.status).compareTo(_sortOrder(b.pact.archived, b.pact.status));
        if (cmp != 0) return cmp;
        if (a.pact.status == PactStatus.active) {
          return (a.nextShowupAt ?? DateTime(9999)).compareTo(b.nextShowupAt ?? DateTime(9999));
        }
        return a.pact.endDate.compareTo(b.pact.endDate);
      });
    return base.copyWith(entries: updated);
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

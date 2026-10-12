import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_signals.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_state.dart';

final pactChecklistSectionViewModelProvider =
    AutoDisposeNotifierProviderFamily<PactChecklistSectionViewModel, PactChecklistSectionState, String>(
  PactChecklistSectionViewModel.new,
);

/// Drives the pact-detail checklist section; separate from `PactDetailViewModel` (GH #464).
class PactChecklistSectionViewModel extends AutoDisposeFamilyNotifier<PactChecklistSectionState, String> {
  bool _disposed = false;

  /// Bumped by every state-changing action; a `load()` that started under an older
  /// generation drops its (possibly stale) result.
  int _generation = 0;

  /// True while Select/Change/Remove is in flight; further taps are ignored.
  bool _busy = false;

  @override
  PactChecklistSectionState build(String pactId) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    // A selection callback was applied elsewhere (the navigator): re-read the link.
    ref.listen(checklistSectionRefreshSignalProvider, (_, __) => unawaited(load()));
    ref.listen(checklistNoChecklistsNoticeProvider(pactId), (_, raised) {
      if (raised) _consumeNotice();
    });
    // The notice may have been raised before this VM existed (cold start).
    if (ref.read(checklistNoChecklistsNoticeProvider(pactId))) {
      unawaited(Future.microtask(_consumeNotice));
      return const PactChecklistSectionState(error: PactChecklistSectionError.noChecklists);
    }
    return const PactChecklistSectionState();
  }

  /// Shows the notice as an error and clears it so a stale `true` never lingers.
  void _consumeNotice() {
    if (_disposed) return;
    state = state.copyWith(error: PactChecklistSectionError.noChecklists);
    ref.read(checklistNoChecklistsNoticeProvider(arg).notifier).state = false;
  }

  /// Reads the pact's current link.
  Future<void> load() async {
    final generation = ++_generation;
    final link = await ref.read(pactChecklistLinkRepositoryProvider).getForPact(arg);
    if (_disposed || generation != _generation) return;
    state = state.copyWith(isLoaded: true, link: link, clearLink: link == null);
  }

  /// Opens Checklister's picker.
  Future<void> startSelection() async {
    if (_busy) return;
    _busy = true;
    try {
      ref.read(checklistNoChecklistsNoticeProvider(arg).notifier).state = false;
      state = state.copyWith(clearError: true);
      final opened = await ref.read(checklistServiceProvider).startSelection(arg);
      if (_disposed || opened) return;
      state = state.copyWith(error: PactChecklistSectionError.couldNotOpen);
    } finally {
      _busy = false;
    }
  }

  /// Removes the link.
  Future<void> remove() async {
    if (_busy) return;
    _busy = true;
    _generation++; // drop any load already in flight
    try {
      await ref.read(checklistServiceProvider).unlink(arg);
      _generation++;
      if (_disposed) return;
      state = state.copyWith(clearLink: true, clearError: true);
    } finally {
      _busy = false;
    }
  }
}

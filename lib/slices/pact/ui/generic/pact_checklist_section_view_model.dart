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

  @override
  PactChecklistSectionState build(String pactId) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    // A selection callback was applied elsewhere (the navigator): re-read the link.
    ref.listen(checklistSectionRefreshSignalProvider, (_, __) => unawaited(load()));
    ref.listen(checklistNoChecklistsNoticeProvider(pactId), (_, raised) {
      if (raised) state = state.copyWith(error: PactChecklistSectionError.noChecklists);
    });
    return const PactChecklistSectionState();
  }

  /// Reads the pact's current link.
  Future<void> load() async {
    final link = await ref.read(pactChecklistLinkRepositoryProvider).getForPact(arg);
    if (_disposed) return;
    state = state.copyWith(isLoaded: true, link: link, clearLink: link == null);
  }

  /// Opens Checklister's picker.
  Future<void> startSelection() async {
    ref.read(checklistNoChecklistsNoticeProvider(arg).notifier).state = false;
    state = state.copyWith(clearError: true);
    final opened = await ref.read(checklistServiceProvider).startSelection(arg);
    if (_disposed || opened) return;
    state = state.copyWith(error: PactChecklistSectionError.couldNotOpen);
  }

  /// Removes the link.
  Future<void> remove() async {
    await ref.read(checklistServiceProvider).unlink(arg);
    if (_disposed) return;
    state = state.copyWith(clearLink: true, clearError: true);
  }
}

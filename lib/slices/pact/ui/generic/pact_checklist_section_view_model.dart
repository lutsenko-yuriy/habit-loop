import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_state.dart';

final pactChecklistSectionViewModelProvider =
    AutoDisposeNotifierProviderFamily<PactChecklistSectionViewModel, PactChecklistSectionState, String>(
  PactChecklistSectionViewModel.new,
);

/// Drives the pact-detail checklist section; separate from `PactDetailViewModel` (GH #464).
class PactChecklistSectionViewModel extends AutoDisposeFamilyNotifier<PactChecklistSectionState, String> {
  @override
  PactChecklistSectionState build(String pactId) => const PactChecklistSectionState();

  /// Reads the pact's current link.
  Future<void> load() async => throw UnimplementedError();

  /// Opens Checklister's picker.
  Future<void> startSelection() async => throw UnimplementedError();

  /// Removes the link.
  Future<void> remove() async => throw UnimplementedError();
}

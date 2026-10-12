import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after a Checklister selection callback was applied, so an open
/// pact-detail checklist section reloads its link.
final checklistSectionRefreshSignalProvider = StateProvider<int>((ref) => 0);

/// Set when a selection callback for the pact reported "no checklists" (Q6).
final checklistNoChecklistsNoticeProvider = StateProvider.family<bool, String>((ref, pactId) => false);

import 'package:habit_loop/domain/checklist/pact_checklist_link_repository.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_gateway.dart';

/// What [ChecklistService.applySelection] did with a selection callback.
enum SelectionOutcome {
  /// The pact's link was created or replaced.
  linked,

  /// The callback matched the existing link; nothing changed.
  unchanged,

  /// The user backed out of the picker.
  cancelled,

  /// Checklister has no checklists to pick from.
  noChecklists,

  /// Stale or malformed: pact missing/not active, or `selected` without id/name.
  ignored,
}

/// Link / unlink / selection-callback logic for a pact's Checklister checklist (GH #464).
class ChecklistService {
  ChecklistService({
    required PactChecklistLinkRepository linkRepository,
    required PactRepository pactRepository,
    required ChecklisterGateway gateway,
    required AnalyticsService analytics,
    DateTime Function()? now,
  });

  /// Opens Checklister's picker for [pactId]. Returns `false` if the pact is not
  /// active or Checklister could not be opened.
  Future<bool> startSelection(String pactId) async => throw UnimplementedError();

  /// Applies a parsed selection callback.
  Future<SelectionOutcome> applySelection(SelectionCallback callback) async => throw UnimplementedError();

  /// Removes the pact's link; no-op if none.
  Future<void> unlink(String pactId) async => throw UnimplementedError();
}

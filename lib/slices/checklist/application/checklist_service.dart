import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link_repository.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_gateway.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';

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
  })  : _links = linkRepository,
        _pacts = pactRepository,
        _gateway = gateway,
        _analytics = analytics,
        _now = now ?? DateTime.now;

  final PactChecklistLinkRepository _links;
  final PactRepository _pacts;
  final ChecklisterGateway _gateway;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  Future<bool> _isActive(String pactId) async => (await _pacts.getPactById(pactId))?.status == PactStatus.active;

  /// Opens Checklister's picker for [pactId]. Returns `false` if the pact is not
  /// active or Checklister could not be opened.
  Future<bool> startSelection(String pactId) async {
    if (!await _isActive(pactId)) return false;
    final existing = await _links.getForPact(pactId);
    final opened = await _gateway.launchSelect(ChecklisterLinks.selectedCallback(pactId).toString());
    if (!opened) return false;
    await _analytics.logEvent(
      PactChecklistSelectionStartedEvent(pactId: pactId, mode: existing == null ? 'select' : 'change'),
    );
    return true;
  }

  /// Applies a parsed selection callback.
  Future<SelectionOutcome> applySelection(SelectionCallback callback) async {
    final pactId = callback.pactId;
    if (!await _isActive(pactId)) return SelectionOutcome.ignored;
    switch (callback.status) {
      case ChecklisterCallbackStatus.selected:
        final id = callback.checklistId;
        final name = callback.checklistName;
        if (id == null || name == null) return SelectionOutcome.ignored;
        // Read at callback time: the mode reflects the link as it is now, not when the picker opened.
        final existing = await _links.getForPact(pactId);
        if (existing != null && existing.checklistId == id) {
          if (existing.checklistName != name) {
            await _links.upsert(PactChecklistLink(
              pactId: pactId,
              checklistId: id,
              checklistName: name,
              linkedAt: existing.linkedAt,
            ));
          }
          return SelectionOutcome.unchanged;
        }
        await _links.upsert(PactChecklistLink(pactId: pactId, checklistId: id, checklistName: name, linkedAt: _now()));
        await _analytics
            .logEvent(PactChecklistLinkedEvent(pactId: pactId, mode: existing == null ? 'select' : 'change'));
        return SelectionOutcome.linked;
      case ChecklisterCallbackStatus.error:
        return SelectionOutcome.noChecklists;
      case ChecklisterCallbackStatus.cancelled:
      case ChecklisterCallbackStatus.completed:
        return SelectionOutcome.cancelled;
    }
  }

  /// Removes the pact's link; no-op if none.
  Future<void> unlink(String pactId) async {
    final existing = await _links.getForPact(pactId);
    if (existing == null) return;
    await _links.delete(pactId);
    await _analytics.logEvent(
      PactChecklistUnlinkedEvent(pactId: pactId, daysLinked: _now().difference(existing.linkedAt).inDays),
    );
  }
}

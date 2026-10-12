import 'package:habit_loop/domain/checklist/checklist_gate.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/checklist_run_repository.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link_repository.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
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

/// What [ChecklistService.startRun] did.
enum RunStartOutcome {
  /// The run was recorded and Checklister opened.
  launched,

  /// The run was recorded but Checklister could not be opened.
  couldNotOpen,

  /// No link, or the showup's run has already finished.
  notRunnable,
}

/// Link / unlink / selection-callback / run start-and-finish logic for a pact's Checklister checklist (GH #464).
class ChecklistService {
  ChecklistService({
    required PactChecklistLinkRepository linkRepository,
    required ChecklistRunRepository runRepository,
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required ChecklisterGateway gateway,
    required AnalyticsService analytics,
    DateTime Function()? now,
  })  : _links = linkRepository,
        _runs = runRepository,
        _pacts = pactRepository,
        _showups = showupRepository,
        _gateway = gateway,
        _analytics = analytics,
        _now = now ?? DateTime.now;

  final PactChecklistLinkRepository _links;
  final ChecklistRunRepository _runs;
  final PactRepository _pacts;
  final ShowupRepository _showups;
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

  /// The showup's checklist gate, plus the finished run's outcome when unlocked.
  Future<({ChecklistGate gate, ChecklistRunOutcome? outcome})> statusFor({
    required String pactId,
    required String showupId,
    required bool flagEnabled,
    required bool installed,
  }) async {
    if (!flagEnabled || !installed) return (gate: ChecklistGate.none, outcome: null);
    final link = await _links.getForPact(pactId);
    final run = link == null ? null : await _runs.getForShowup(showupId);
    final gate = ChecklistGate.resolve(flagEnabled: true, checklisterInstalled: true, link: link, run: run);
    return (gate: gate, outcome: gate == ChecklistGate.unlocked ? run?.outcome : null);
  }

  /// Records the run start, then opens Checklister to run the pact's checklist.
  /// The record is written first so a callback racing the launch finds it.
  Future<RunStartOutcome> startRun({required String pactId, required String showupId}) async {
    final link = await _links.getForPact(pactId);
    if (link == null) return RunStartOutcome.notRunnable;
    final run = await _runs.upsertStarted(
      showupId: showupId,
      pactId: pactId,
      checklistId: link.checklistId,
      startedAt: _now(),
    );
    if (run.isFinished) return RunStartOutcome.notRunnable;
    final callback = ChecklisterLinks.runFinishedCallback(pactId, showupId).toString();
    if (!await _gateway.launchRun(link.checklistId, callback)) return RunStartOutcome.couldNotOpen;
    await _analytics.logEvent(ChecklistRunStartedEvent(pactId: pactId));
    return RunStartOutcome.launched;
  }

  /// Finishes the showup's started run from a run-finished callback. Returns the
  /// outcome, or `null` when ignored: no matching unfinished run (spoofed or
  /// duplicate callback) or a non-run status.
  Future<ChecklistRunOutcome?> applyRunResult(RunCallback callback) async {
    final outcome = switch (callback.status) {
      ChecklisterCallbackStatus.completed => ChecklistRunOutcome.success,
      ChecklisterCallbackStatus.cancelled || ChecklisterCallbackStatus.error => ChecklistRunOutcome.failure,
      ChecklisterCallbackStatus.selected => null,
    };
    if (outcome == null) return null;
    final run = await _runs.getForShowup(callback.showupId);
    if (run == null || run.isFinished || run.pactId != callback.pactId || run.checklistId != callback.checklistId) {
      return null;
    }
    final finishedAt = _now();
    final finished = await _runs.markFinished(showupId: callback.showupId, finishedAt: finishedAt, outcome: outcome);
    if (finished == null) return null;
    final showup = await _showups.getShowupById(callback.showupId);
    final windowEnd = showup?.scheduledAt.add(showup.duration);
    await _analytics.logEvent(ChecklistRunFinishedEvent(
      pactId: callback.pactId,
      outcome: outcome,
      windowClosedMeanwhile: windowEnd != null && !run.startedAt.isAfter(windowEnd) && finishedAt.isAfter(windowEnd),
    ));
    return outcome;
  }
}

import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';

/// Fired when Checklister is opened to pick a checklist for a pact. (GH #464)
final class PactChecklistSelectionStartedEvent extends AnalyticsEvent {
  PactChecklistSelectionStartedEvent({required this.pactId, required this.mode});

  final String pactId;

  /// `select` | `change`
  final String mode;

  @override
  String get name => 'pact_checklist_selection_started';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId, 'mode': mode};
}

/// Fired when a selection callback changes the pact's link. (GH #464)
final class PactChecklistLinkedEvent extends AnalyticsEvent {
  PactChecklistLinkedEvent({required this.pactId, required this.mode});

  final String pactId;

  /// `select` | `change`
  final String mode;

  @override
  String get name => 'pact_checklist_linked';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId, 'mode': mode};
}

/// Fired when the user removes the pact's checklist link. (GH #464)
final class PactChecklistUnlinkedEvent extends AnalyticsEvent {
  PactChecklistUnlinkedEvent({required this.pactId, required this.daysLinked});

  final String pactId;
  final int daysLinked;

  @override
  String get name => 'pact_checklist_unlinked';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId, 'days_linked': daysLinked};
}

/// Fired when "Run checklist" opens Checklister for a showup. (GH #464)
final class ChecklistRunStartedEvent extends AnalyticsEvent {
  ChecklistRunStartedEvent({required this.pactId});

  final String pactId;

  @override
  String get name => 'checklist_run_started';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId};
}

/// Fired when Checklister reports a run's outcome back. (GH #464)
final class ChecklistRunFinishedEvent extends AnalyticsEvent {
  ChecklistRunFinishedEvent({required this.pactId, required this.outcome, required this.windowClosedMeanwhile});

  final String pactId;
  final ChecklistRunOutcome outcome;
  final bool windowClosedMeanwhile;

  @override
  String get name => 'checklist_run_finished';

  @override
  Map<String, Object?> toParameters() =>
      {'pact_id': pactId, 'outcome': outcome.name, 'window_closed_meanwhile': windowClosedMeanwhile};
}

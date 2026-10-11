import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';

/// Fired when Checklister is opened to pick a checklist for a pact. (GH #464)
final class PactChecklistSelectionStartedEvent extends AnalyticsEvent {
  PactChecklistSelectionStartedEvent({required this.pactId, required this.mode});

  final String pactId;

  /// `select` | `change`
  final String mode;

  @override
  String get name => throw UnimplementedError();

  @override
  Map<String, Object?> toParameters() => throw UnimplementedError();
}

/// Fired when a selection callback changes the pact's link. (GH #464)
final class PactChecklistLinkedEvent extends AnalyticsEvent {
  PactChecklistLinkedEvent({required this.pactId, required this.mode});

  final String pactId;

  /// `select` | `change`
  final String mode;

  @override
  String get name => throw UnimplementedError();

  @override
  Map<String, Object?> toParameters() => throw UnimplementedError();
}

/// Fired when the user removes the pact's checklist link. (GH #464)
final class PactChecklistUnlinkedEvent extends AnalyticsEvent {
  PactChecklistUnlinkedEvent({required this.pactId, required this.daysLinked});

  final String pactId;
  final int daysLinked;

  @override
  String get name => throw UnimplementedError();

  @override
  Map<String, Object?> toParameters() => throw UnimplementedError();
}

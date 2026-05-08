import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';

/// Fired when the user manually marks a showup as done.
final class ShowupMarkedDoneEvent extends AnalyticsEvent {
  ShowupMarkedDoneEvent({required this.pactId});

  /// ID of the parent pact.
  final String pactId;

  @override
  String get name => 'showup_marked_done';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId};
}

/// Fired when the user manually marks a showup as failed (not auto-fail).
final class ShowupMarkedFailedEvent extends AnalyticsEvent {
  ShowupMarkedFailedEvent({required this.pactId});

  /// ID of the parent pact.
  final String pactId;

  @override
  String get name => 'showup_marked_failed';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId};
}

/// Fired when a showup is automatically transitioned to failed because its
/// scheduled window has passed — triggered on dashboard load/refresh or when
/// the showup detail screen is opened.
final class ShowupAutoFailedEvent extends AnalyticsEvent {
  ShowupAutoFailedEvent({required this.pactId});

  /// ID of the parent pact.
  final String pactId;

  @override
  String get name => 'showup_auto_failed';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId};
}

/// Screen identifier for the showup detail screen.
class ShowupDetailAnalyticsScreen implements AnalyticsScreen {
  const ShowupDetailAnalyticsScreen();

  @override
  String get name => 'showup_detail';
}

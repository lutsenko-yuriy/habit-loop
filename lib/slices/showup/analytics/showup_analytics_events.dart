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

/// Fired when an auto-failed showup is successfully redeemed (marked done via the redemption path).
final class ShowupRedeemedEvent extends AnalyticsEvent {
  ShowupRedeemedEvent({
    required this.pactId,
    required this.noteLength,
    required this.daysSinceScheduled,
  });

  final String pactId;

  /// Length of the note (in characters) at redemption time. Never the note content.
  final int noteLength;

  /// Calendar days between scheduledAt and the redemption moment (floored).
  final int daysSinceScheduled;

  @override
  String get name => 'showup_redeemed';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'note_length': noteLength,
        'days_since_scheduled': daysSinceScheduled,
      };
}

/// Fired on showup detail screen load when the redemption button is visible but
/// disabled because the showup note is empty.
final class ShowupRedemptionBlockedEvent extends AnalyticsEvent {
  ShowupRedemptionBlockedEvent({required this.pactId});

  final String pactId;

  @override
  String get name => 'showup_redemption_blocked';

  @override
  Map<String, Object?> toParameters() => {'pact_id': pactId};
}

/// Screen identifier for the showup detail screen.
class ShowupDetailAnalyticsScreen implements AnalyticsScreen {
  const ShowupDetailAnalyticsScreen();

  @override
  String get name => 'showup_detail';
}

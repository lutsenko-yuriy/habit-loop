import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';

/// Fired each time the reminder scheduling job completes (on pact creation
/// and on any re-schedule pass such as a dashboard refresh).
final class NotificationsScheduledEvent extends AnalyticsEvent {
  NotificationsScheduledEvent({
    required this.pactId,
    required this.notificationsCount,
    required this.reminderOffsetMinutes,
  });

  /// ID of the pact whose notifications were scheduled.
  final String pactId;

  /// Number of notifications registered with the OS.
  ///
  /// May be less than the total number of showups due to OS limits
  /// (iOS caps pending notifications at 64).
  final int notificationsCount;

  /// Reminder offset in minutes — mirrors the `reminder_offset_minutes`
  /// property of `pact_created`.
  final int reminderOffsetMinutes;

  @override
  String get name => 'notifications_scheduled';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'notifications_count': notificationsCount,
        'reminder_offset_minutes': reminderOffsetMinutes,
      };
}

/// Fired when the app is opened (cold-started or resumed from background)
/// because the user tapped a reminder notification.
///
/// Fires from the navigation layer using data already present in the
/// notification payload — no DB round-trip is needed.
final class AppOpenedFromNotificationEvent extends AnalyticsEvent {
  AppOpenedFromNotificationEvent({
    required this.pactId,
    required this.showupId,
    required this.coldStart,
  });

  /// ID of the parent pact from the notification payload.
  final String pactId;

  /// ID of the showup from the notification payload.
  final String showupId;

  /// `true` if the app was launched from a killed state (cold start);
  /// `false` if resumed from background (warm start).
  final bool coldStart;

  @override
  String get name => 'app_opened_from_notification';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'showup_id': showupId,
        'cold_start': coldStart,
      };
}

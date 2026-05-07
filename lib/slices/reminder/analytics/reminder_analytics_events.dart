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

/// Fired when the user taps a reminder notification and the app opens to the
/// showup detail screen.
final class NotificationOpenedEvent extends AnalyticsEvent {
  NotificationOpenedEvent({
    required this.pactId,
    required this.minutesBeforeShowup,
  });

  /// Parent pact ID.
  final String pactId;

  /// Minutes before the scheduled showup time when the notification was tapped.
  ///
  /// Negative values mean the notification was tapped after the showup window
  /// started.
  final int minutesBeforeShowup;

  @override
  String get name => 'notification_opened';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'minutes_before_showup': minutesBeforeShowup,
      };
}

/// Fired when the user marks a showup done from a notification action button
/// without opening the app (stretch goal — actionable notifications only).
///
/// Additive to `showup_marked_done`: both fire when the user acts from the
/// notification tray.
final class ShowupMarkedDoneFromNotificationEvent extends AnalyticsEvent {
  ShowupMarkedDoneFromNotificationEvent({required this.pactId});

  /// Parent pact ID.
  final String pactId;

  @override
  String get name => 'showup_marked_done_from_notification';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
      };
}

import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';

/// Fired each time the reminder scheduling job completes (on pact creation
/// and on any re-schedule pass such as a dashboard refresh).
final class NotificationsScheduledEvent extends AnalyticsEvent {
  NotificationsScheduledEvent({
    required this.pactId,
    required this.notificationsCount,
    required this.reminderOffsetMinutes,
    this.hurryUpCount = 0,
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

  /// Number of hurry-up notifications included in [notificationsCount]
  /// (HAB-246). `0` when the feature is disabled or no showup qualified.
  final int hurryUpCount;

  @override
  String get name => 'notifications_scheduled';

  @override
  Map<String, Object?> toParameters() => {
        'pact_id': pactId,
        'notifications_count': notificationsCount,
        'reminder_offset_minutes': reminderOffsetMinutes,
        'hurry_up_count': hurryUpCount,
      };
}

/// Fired at the end of a [NotificationReconciliationService.reconcile] run
/// that actually changed something (HAB-254) — never fired for a no-drift
/// run, so this event's volume itself signals how often drift occurs.
final class NotificationsReconciledEvent extends AnalyticsEvent {
  NotificationsReconciledEvent({
    required this.rescheduledCount,
    required this.cancelledCount,
  });

  /// Number of individual notifications (reminder/deadline/hurry-up, summed
  /// across showups) that were missing from the OS and got (re)scheduled.
  final int rescheduledCount;

  /// Number of showups whose stale notifications were cancelled because they
  /// no longer belong in the desired set (e.g. now covered by a break).
  final int cancelledCount;

  @override
  String get name => 'notifications_reconciled';

  @override
  Map<String, Object?> toParameters() => {
        'rescheduled_count': rescheduledCount,
        'cancelled_count': cancelledCount,
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

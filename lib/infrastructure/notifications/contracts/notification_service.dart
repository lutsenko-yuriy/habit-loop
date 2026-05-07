import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';

/// Abstract interface for scheduling and cancelling local notifications.
///
/// Inject via Riverpod (`notificationServiceProvider`) so call sites are
/// decoupled from the `flutter_local_notifications` SDK. Tests override with
/// a fake.
///
/// **No-throw contract:** all implementations must swallow exceptions
/// internally. Call sites may call any method without wrapping them in
/// try/catch blocks.
abstract interface class NotificationService {
  /// Initialises the notifications plugin.
  ///
  /// Must be called once before any other method. Creates the Android
  /// notification channel (`showup_reminders`) and retrieves
  /// app-launch notification details for cold-start deep-link handling.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> initialize();

  /// Requests notification permission on iOS.
  ///
  /// Returns `true` if permission was granted, `false` otherwise.
  /// On Android this is a no-op and always returns `true`.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<bool> requestPermission();

  /// Schedules a reminder notification for [showup].
  ///
  /// The notification fires at `showup.scheduledAt - pact.reminderOffset`.
  /// The notification ID is derived from `showup.scheduledAt.millisecondsSinceEpoch ~/ 1000`
  /// so it is deterministic and fits in a 32-bit integer.
  /// The payload JSON includes `showupId` and `pactId` for deep-link navigation.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> scheduleShowupReminder({
    required Showup showup,
    required Pact pact,
    required String titleText,
    required String bodyText,
  });

  /// Schedules a "missed deadline" replacement notification for [showup].
  ///
  /// Uses the same notification ID as the reminder so it replaces the original
  /// in the notification tray. Fires at `showup.scheduledAt + showup.duration`.
  /// Has no action buttons — the showup window has passed.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> scheduleDeadlineNotification({
    required Showup showup,
    required String titleText,
    required String bodyText,
  });

  /// Cancels both the reminder and deadline notifications for the given showup.
  ///
  /// Uses [scheduledAt] to recompute the notification ID
  /// (`scheduledAt.millisecondsSinceEpoch ~/ 1000`).
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> cancelShowupReminder(String showupId, DateTime scheduledAt);

  /// Cancels all pending notifications for the given pact.
  ///
  /// Because `flutter_local_notifications` has no cancel-by-tag API, this
  /// implementation maintains an in-memory registry of notification IDs keyed
  /// by pact ID. On app restart the registry is empty; the implementation falls
  /// back to fetching all pending notifications and filtering by the `pactId`
  /// field in their payload JSON.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> cancelAllRemindersForPact(String pactId);

  /// Returns all currently pending notifications scheduled with the OS.
  ///
  /// Useful for diagnostics and test assertions.
  ///
  /// Never throws — implementations return an empty list on failure.
  Future<List<PendingNotificationRequest>> getPendingNotifications();

  /// Returns the notification details that launched the app, if any.
  ///
  /// Returns `null` on platforms that do not support this API or when the app
  /// was not launched from a notification.
  ///
  /// Never throws — implementations return `null` on failure.
  Future<NotificationAppLaunchDetails?> getAppLaunchDetails();
}

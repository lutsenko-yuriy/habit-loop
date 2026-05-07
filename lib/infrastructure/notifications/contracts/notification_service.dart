import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';

/// Platform-agnostic representation of a pending scheduled notification.
///
/// Mirrors the fields from `flutter_local_notifications`
/// `PendingNotificationRequest` but uses only plain Dart types so the
/// interface does not leak SDK types.
class PendingNotificationInfo {
  const PendingNotificationInfo({required this.id, this.title, this.body, this.payload});

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

/// Platform-agnostic representation of notification launch details.
///
/// Returned by [NotificationService.getAppLaunchDetails] when the app was
/// opened via a notification tap. Uses only plain Dart types so the interface
/// does not leak SDK types.
class NotificationLaunchInfo {
  const NotificationLaunchInfo({required this.didNotificationLaunchApp, this.payload});

  /// Whether the app was launched by tapping a notification.
  final bool didNotificationLaunchApp;

  /// The raw payload string from the notification, if any.
  final String? payload;
}

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
  /// The reminder notification ID is derived from `showup.id.hashCode.abs() % 2147483647`
  /// so it is deterministic, collision-resistant, and fits in a 32-bit signed integer.
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
  /// Uses a different notification ID from the reminder so both can coexist in the
  /// notification tray. The deadline ID is `(showup.id.hashCode.abs() % 1073741823) + 1073741824`.
  /// Fires at `showup.scheduledAt + showup.duration`.
  /// Has no action buttons — the showup window has passed.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> scheduleDeadlineNotification({
    required Showup showup,
    required String titleText,
    required String bodyText,
  });

  /// Cancels both the reminder and deadline notifications for [showupId].
  ///
  /// Recomputes both notification IDs from [showupId] — no [DateTime] parameter
  /// is needed because the IDs are derived solely from the showup UUID.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> cancelShowupReminder(String showupId);

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
  /// Useful for diagnostics and test assertions. Returns plain [PendingNotificationInfo]
  /// objects — no SDK types leak through this interface.
  ///
  /// Never throws — implementations return an empty list on failure.
  Future<List<PendingNotificationInfo>> getPendingNotifications();

  /// Returns the notification details that launched the app, if any.
  ///
  /// Returns `null` on platforms that do not support this API or when the app
  /// was not launched from a notification. Returns a plain [NotificationLaunchInfo]
  /// — no SDK types leak through this interface.
  ///
  /// Never throws — implementations return `null` on failure.
  Future<NotificationLaunchInfo?> getAppLaunchDetails();
}

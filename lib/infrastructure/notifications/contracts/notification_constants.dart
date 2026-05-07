/// Shared constants for notification action IDs and notification ID computation.
///
/// Used by both [FlutterLocalNotificationService] and the background/foreground
/// notification handlers in `main.dart` so that cancellation calls always use
/// the same IDs as the original scheduling calls.
///
/// **IMPORTANT:** The ID formulas in [reminderNotificationId] and
/// [deadlineNotificationId] must stay in sync with any direct cancellation
/// calls in `main.dart`. If you change the formula here, update every call
/// site that constructs notification IDs independently.
abstract final class NotificationConstants {
  /// Action ID for the "Mark done" notification action button.
  ///
  /// Must match the action ID registered in the iOS notification category
  /// ([DarwinNotificationCategory]) and the Android action
  /// ([AndroidNotificationAction]).
  static const String markDoneActionId = 'mark_done';

  /// Computes the OS notification ID for a showup reminder.
  ///
  /// Range: `[0, 2147483646]` — fits within a 32-bit signed integer.
  static int reminderNotificationId(String showupId) => showupId.hashCode.abs() % 2147483647;

  /// Computes the OS notification ID for a showup deadline notification.
  ///
  /// Range: `[1073741824, 2147483646]` — disjoint from [reminderNotificationId]
  /// so both notifications can coexist in the notification tray simultaneously.
  static int deadlineNotificationId(String showupId) => (showupId.hashCode.abs() % 1073741823) + 1073741824;
}

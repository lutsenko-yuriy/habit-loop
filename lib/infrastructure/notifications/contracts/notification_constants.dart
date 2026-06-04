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
  /// Range: `[0, 1073741823]` — lower half of the 32-bit signed integer space,
  /// disjoint from [deadlineNotificationId].
  ///
  /// Uses FNV-1a 32-bit so the result is stable across Dart VM restarts.
  /// `String.hashCode` must NOT be used here because Dart randomises the hash
  /// seed per process, causing IDs to differ between the scheduling session
  /// and a subsequent cancellation session after a cold restart.
  static int reminderNotificationId(String showupId) => _fnv1a32(showupId) % 1073741824;

  /// Computes the OS notification ID for a showup deadline notification.
  ///
  /// Range: `[1073741824, 2147483646]` — disjoint from [reminderNotificationId]
  /// so both notifications can coexist in the notification tray simultaneously.
  ///
  /// Uses FNV-1a 32-bit for the same stability reason as [reminderNotificationId].
  static int deadlineNotificationId(String showupId) => (_fnv1a32(showupId) % 1073741823) + 1073741824;

  /// FNV-1a 32-bit hash — deterministic, no per-process seed, no dependencies.
  ///
  /// Produces values in `[0, 0xFFFFFFFF]`. Masking with `& 0xFFFFFFFF` keeps
  /// Dart's arbitrary-precision integers within 32 bits after each multiply.
  static int _fnv1a32(String s) {
    var h = 0x811c9dc5; // FNV offset basis
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF; // FNV prime
    }
    return h;
  }
}

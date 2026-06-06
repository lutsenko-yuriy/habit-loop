/// Shared notification action IDs and ID formulas.
///
/// Single source of truth used by [FlutterLocalNotificationService] and the
/// `main.dart` background handler — cancellation must use the same IDs as
/// scheduling, so any formula change must be reflected everywhere.
abstract final class NotificationConstants {
  static const String markDoneActionId = 'mark_done';

  /// Range `[0x0, 0x3FFFFFFF]` — disjoint from [deadlineNotificationId].
  ///
  /// Uses FNV-1a 32-bit, not `String.hashCode`. Dart randomises the hashCode
  /// seed per process, so IDs would differ between scheduling and cancellation
  /// sessions after a cold restart.
  static int reminderNotificationId(String showupId) => _fnv1a32(showupId) % 0x40000000;

  /// Range `[0x40000000, 0x7FFFFFFE]` — disjoint from [reminderNotificationId].
  static int deadlineNotificationId(String showupId) => (_fnv1a32(showupId) % 0x3FFFFFFF) + 0x40000000;

  /// FNV-1a 32-bit — deterministic across Dart VM restarts (no per-process seed).
  static int _fnv1a32(String s) {
    var h = 0x811c9dc5; // FNV offset basis
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF; // FNV prime
    }
    return h;
  }
}

/// Shared notification ID formulas used by scheduling and cancellation.
///
/// Single source of truth — cancellation must use the same IDs as scheduling,
/// so any formula change must be reflected everywhere.
abstract final class NotificationConstants {
  /// Lower bound of [deadlineNotificationId]'s range — any id `>=` this came
  /// from a deadline notification, not a reminder one (see below). Used to
  /// classify an already-scheduled id (e.g. from [PendingNotificationInfo])
  /// without needing to recompute both formulas.
  static const int deadlineRangeStart = 0x40000000;

  /// Range `[0x0, 0x3FFFFFFF]` — disjoint from [deadlineNotificationId].
  ///
  /// Uses FNV-1a 32-bit, not `String.hashCode`. Dart randomises the hashCode
  /// seed per process, so IDs would differ between scheduling and cancellation
  /// sessions after a cold restart.
  static int reminderNotificationId(String showupId) => _fnv1a32(showupId) % 0x40000000;

  /// Range `[0x40000000, 0x7FFFFFFE]` — disjoint from [reminderNotificationId].
  static int deadlineNotificationId(String showupId) => (_fnv1a32(showupId) % 0x3FFFFFFF) + deadlineRangeStart;

  /// Range `[-0x40000000, -1]` — disjoint from both [reminderNotificationId] and
  /// [deadlineNotificationId] (HAB-246).
  ///
  /// Deliberately uses the negative int32 space rather than re-partitioning
  /// the positive range three ways: the positive space is fully spent by the
  /// two existing formulas, and changing either of them would orphan every
  /// deadline/reminder notification already scheduled with the OS on an
  /// installed build (cancellation recomputes IDs from the showup UUID).
  /// Confirmed safe on both platforms — see `docs/knowledge/notes/HAB-246.md`.
  static int hurryUpNotificationId(String showupId) => -((_fnv1a32(showupId) % 0x40000000) + 1);

  /// True for any id produced by [hurryUpNotificationId] — the negative range
  /// is disjoint from [reminderNotificationId]/[deadlineNotificationId], both
  /// of which are always non-negative, so sign alone classifies it.
  static bool isHurryUpNotificationId(int id) => id < 0;

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

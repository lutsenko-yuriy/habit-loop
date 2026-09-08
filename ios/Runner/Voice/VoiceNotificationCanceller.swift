// HAB-269 WU2 — cancels a showup's pending reminder/deadline/hurry-up local
// notifications after a native (Siri) mark-done, mirroring
// ReminderSchedulingService.cancelRemindersForShowup's Dart-side behaviour so
// the user isn't nagged about something they just told Siri they finished.
//
// Chose native reimplementation over routing through the Darwin-notification/
// EventChannel bridge (VoiceWriteSignal) this WU already builds: that bridge
// only reaches a *live* Dart engine, and a backgrounded/killed-app AppIntent
// (this feature's whole reason for existing — see VoiceShowupStore's header
// comment) has no live engine to deliver the event to until the user next
// opens the app, which could be long after the notifications have already
// re-fired. The Dart formula (NotificationConstants, FNV-1a 32-bit hash of
// the showup id) is pure and has no native SDK dependency, so porting it here
// is a handful of lines, not a second scheduling implementation.
//
// Single source of truth for the id formulas is
// lib/infrastructure/notifications/contracts/notification_constants.dart —
// any drift there must be mirrored here too. flutter_local_notifications'
// iOS/macOS implementation registers every UNNotificationRequest with
// `identifier: String(id)` (confirmed against its own source), which is why
// cancellation here works from ids alone with no other native-side state.

import Foundation
import UserNotifications

enum VoiceNotificationCanceller {
  static func cancel(showupId: String) {
    let identifiers = [
      reminderNotificationId(showupId),
      deadlineNotificationId(showupId),
      hurryUpNotificationId(showupId),
    ].map(String.init)
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
  }

  private static let deadlineRangeStart: Int64 = 0x40000000

  // internal (not private), not for production callers but so RunnerTests
  // can assert these against the same golden values
  // test/infrastructure/notifications/notification_constants_test.dart locks
  // in on the Dart side — the two formulas must never drift apart.
  //
  // Ranges below mirror NotificationConstants exactly (Dart uses `%` on a
  // non-negative operand throughout, so these divisions/mods behave
  // identically in Swift's Int64 arithmetic — no sign-handling divergence).
  static func reminderNotificationId(_ showupId: String) -> Int64 {
    Int64(fnv1a32(showupId)) % 0x40000000
  }

  static func deadlineNotificationId(_ showupId: String) -> Int64 {
    (Int64(fnv1a32(showupId)) % 0x3FFFFFFF) + deadlineRangeStart
  }

  static func hurryUpNotificationId(_ showupId: String) -> Int64 {
    -((Int64(fnv1a32(showupId)) % 0x40000000) + 1)
  }

  /// FNV-1a 32-bit over UTF-16 code units, matching Dart's `String.codeUnits`
  /// exactly (not UTF-8 bytes) — see NotificationConstants._fnv1a32. Showup/
  /// pact ids are always ASCII (`{deviceId}-{uuid}`, hex digits and hyphens),
  /// where a UTF-16 code unit and a UTF-8 byte have the same value, but this
  /// walks `utf16` explicitly so the two implementations would still agree on
  /// any future non-ASCII id.
  static func fnv1a32(_ s: String) -> UInt32 {
    var h: UInt32 = 0x811c9dc5
    for unit in s.utf16 {
      h ^= UInt32(unit)
      h = h &* 0x01000193
    }
    return h
  }
}

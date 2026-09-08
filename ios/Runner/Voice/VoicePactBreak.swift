// HAB-269 WU2 — native port of `PactBreak`'s on-break window predicate
// (lib/domain/pact/pact_break.dart) so VoiceShowupStore can filter out
// on-break showups the same way the in-app rule does (showup_detail_content.dart,
// HAB-213). Only the fields `contains(_:)` needs are carried over — no full
// PactBreak parity is needed on the native side.

import Foundation

struct VoicePactBreak {
  let pactId: String
  let startDate: Date
  let plannedEndDate: Date? // nil = "until pact ends"
  let stoppedAt: Date? // nil = not stopped

  /// Mirrors `PactBreak.contains` literally: before `startDate` is never
  /// covered; once stopped, covered up to (and including) `stoppedAt`;
  /// otherwise covered through the end of `plannedEndDate`'s calendar day
  /// (or forever, if open-ended).
  func contains(_ scheduledAt: Date) -> Bool {
    if scheduledAt < startDate { return false }
    if let stoppedAt {
      return !(scheduledAt > stoppedAt)
    }
    guard let plannedEndDate else { return true }
    return !(scheduledAt > VoicePactBreak.endOfDay(plannedEndDate))
  }

  /// Mirrors `PactBreak.endOfDay` — `plannedEndDate` is a picked calendar
  /// date, not a precise instant, so it must cover the whole day it names.
  static func endOfDay(_ d: Date) -> Date {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: d)
    // Match Dart's DateTime(y, m, d, 23, 59, 59, 999) to the millisecond.
    let almostNextDay = calendar.date(byAdding: DateComponents(day: 1, nanosecond: -1_000_000), to: startOfDay)
    return almostNextDay ?? d
  }
}

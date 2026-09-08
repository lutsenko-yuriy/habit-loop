// HAB-269 WU1 — "which showups today" Siri voice command. No openAppWhenRun: this
// must run without foregrounding, per PRODUCT_SPEC.md's "no unlocking the phone"
// requirement — confirmed working during the WU0 checklist (docs/knowledge/notes/HAB-269.md).
// Analytics logging (voice_today_showups_queried) lands in WU2. Inert in production
// until WU2 flips voice_mark_done_enabled — see VoiceFeatureFlag.swift.

import AppIntents
import Foundation

@available(iOS 16.0, *)
struct TodaysShowupsIntent: AppIntent {
  static var title: LocalizedStringResource = "Which showups today"
  static var description = IntentDescription("Reads back today's remaining habit show-ups.")

  // No @MainActor: perform() does synchronous SQLite I/O and touches no UIKit state.
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard VoiceFeatureFlag.markDoneEnabled else {
      return .result(dialog: "Voice showups aren't available yet.")
    }

    let showups = VoiceShowupStore.todaysOpenShowups()
    if showups.isEmpty {
      return .result(dialog: "Nothing left to do today.")
    }
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    let lines = showups.map { "\($0.habitName) at \(formatter.string(from: $0.scheduledAt))" }
    return .result(dialog: "Today's showups: \(lines.joined(separator: ", ")).")
  }
}

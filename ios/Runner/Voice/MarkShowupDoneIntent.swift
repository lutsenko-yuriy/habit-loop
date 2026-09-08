// HAB-269 WU1 — "mark <habit> done" Siri voice command. See docs/ARCHITECTURE.md's
// Voice section and the plan comment on HAB-269 for the full case-by-case rationale.
// Analytics logging (voice_mark_done_resolved) lands in WU2. Inert in production until
// WU2 flips voice_mark_done_enabled — see VoiceFeatureFlag.swift.
//
// requestConfirmation(result:) does NOT return a Bool (confirmed against Apple's docs):
// it returns the passed-in result on confirm, and *throws* if the user declines.
//
// Case 4 (no match at all) uses requestDisambiguation(among:dialog:) — native Siri
// disambiguation UX, letting the user pick by position ("the first one") — rather than
// custom parsing (docs/knowledge/notes/HAB-269.md, 2026-09-08). This method lives on
// the @Parameter's IntentParameter wrapper (accessed via $habitDescription), not as a
// free function on AppIntent, and its itemsToDisambiguate must match the parameter's
// own declared type — so it disambiguates among habit-name Strings, then looks up the
// matching VoiceShowup by name.

import AppIntents
import Foundation

@available(iOS 16.0, *)
struct MarkShowupDoneIntent: AppIntent {
  static var title: LocalizedStringResource = "Mark a showup done"
  static var description = IntentDescription("Marks today's habit show-up as done.")

  // requestValueDialog drives Siri's spoken follow-up ("Which habit?") when the phrase
  // itself (deliberately static — see HabitLoopShortcuts.swift) didn't supply this value.
  // Free-text params can't be embedded in a phrase directly.
  @Parameter(title: "Habit", requestValueDialog: "Which habit?")
  var habitDescription: String

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard VoiceFeatureFlag.markDoneEnabled else {
      return .result(dialog: "Voice mark-done isn't available yet.")
    }

    let now = Date()
    let todays = VoiceShowupStore.todaysOpenShowups(now: now)
    let pending = VoiceShowupStore.pendingMatches(in: todays, description: habitDescription, now: now)

    // Case 1: exactly one pending match -> mark immediately, no confirmation.
    if pending.count == 1 {
      return .result(dialog: IntentDialog(stringLiteral: mark(pending[0])))
    }

    // Case 3: several pending matches -> confirm the best guess (first match).
    if pending.count > 1 {
      let best = pending[0]
      do {
        _ = try await requestConfirmation(result: .result(dialog: "Did you mean \(best.habitName)?"))
        return .result(dialog: IntentDialog(stringLiteral: mark(best)))
      } catch {
        return .result(dialog: "OK, not marking anything.")
      }
    }

    // Case 2: a future (not-yet-pending) match -> confirm, reminding it isn't due yet.
    let future = VoiceShowupStore.futureMatches(in: todays, description: habitDescription, now: now)
    if let match = future.first {
      do {
        _ = try await requestConfirmation(
          result: .result(dialog: "\(match.habitName) isn't due yet. Mark it done anyway?")
        )
        return .result(dialog: IntentDialog(stringLiteral: mark(match)))
      } catch {
        return .result(dialog: "OK, not marking anything.")
      }
    }

    // Case 4: no match at all -> offer today's remaining pending showups via Siri's
    // native disambiguation UI.
    let candidates = todays.filter { $0.status == "pending" }
    guard !candidates.isEmpty else {
      return .result(dialog: "I couldn't find anything to mark done today.")
    }
    do {
      let chosenName = try await $habitDescription.requestDisambiguation(
        among: candidates.map { $0.habitName },
        dialog: "I couldn't match that to a habit. Which one did you mean?"
      )
      guard let chosen = candidates.first(where: { $0.habitName == chosenName }) else {
        return .result(dialog: "Something went wrong.")
      }
      return .result(dialog: IntentDialog(stringLiteral: mark(chosen)))
    } catch {
      return .result(dialog: "OK, not marking anything.")
    }
  }

  private func mark(_ showup: VoiceShowup) -> String {
    let ok = VoiceShowupStore.markDone(id: showup.id)
    return ok ? "Marked \(showup.habitName) done." : "Something went wrong."
  }
}

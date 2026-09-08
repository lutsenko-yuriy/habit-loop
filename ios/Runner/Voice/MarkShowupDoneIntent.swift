// HAB-269 WU1/WU2 — "mark <habit> done" Siri voice command. See docs/ARCHITECTURE.md's
// Voice section and the plan comment on HAB-269 for the full case-by-case rationale.
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
//
// WU2 additions: on a successful mark, cancels the showup's pending reminder/deadline/
// hurry-up notifications (VoiceNotificationCanceller — see its header comment for why
// native reimplementation was chosen over the Darwin-notification/EventChannel bridge)
// and posts VoiceWriteSignal so a live-in-background Flutter engine refreshes its
// caches. Analytics (voice_mark_done_resolved, showup_marked_done) are logged directly
// via the native FirebaseAnalytics SDK — a deliberate, documented exception to routing
// through Dart's AnalyticsService (docs/ARCHITECTURE.md's Voice section, HAB-269 WU2).

import AppIntents
import FirebaseAnalytics
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

  // No @MainActor: perform() does synchronous SQLite I/O and touches no UIKit state,
  // so it shouldn't compete with the main thread (audit finding, HAB-269 WU1 review).
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard VoiceFeatureFlag.markDoneEnabled else {
      return .result(dialog: "Voice mark-done isn't available yet.")
    }

    let now = Date()
    let todays = VoiceShowupStore.todaysOpenShowups(now: now)
    let pending = VoiceShowupStore.pendingMatches(in: todays, description: habitDescription, now: now)

    // Case 1: exactly one pending match -> mark immediately, no confirmation.
    if pending.count == 1 {
      logResolved(outcome: "marked_direct", candidateCount: pending.count)
      return .result(dialog: IntentDialog(stringLiteral: mark(pending[0])))
    }

    // Case 3: several pending matches -> confirm the best guess (first match).
    if pending.count > 1 {
      let best = pending[0]
      do {
        _ = try await requestConfirmation(result: .result(dialog: "Did you mean \(best.habitName)?"))
        logResolved(outcome: "marked_after_confirmation", candidateCount: pending.count)
        return .result(dialog: IntentDialog(stringLiteral: mark(best)))
      } catch {
        logResolved(outcome: "declined_confirmation", candidateCount: pending.count)
        return .result(dialog: "OK, not marking anything.")
      }
    }

    // Case 2: a future (not-yet-pending) match -> confirm, reminding it isn't due yet.
    // No pending matches at all, so candidate_count is 0 for both outcomes below.
    let future = VoiceShowupStore.futureMatches(in: todays, description: habitDescription, now: now)
    if let match = future.first {
      do {
        _ = try await requestConfirmation(
          result: .result(dialog: "\(match.habitName) isn't due yet. Mark it done anyway?")
        )
        logResolved(outcome: "marked_after_confirmation", candidateCount: 0)
        return .result(dialog: IntentDialog(stringLiteral: mark(match)))
      } catch {
        logResolved(outcome: "declined_confirmation", candidateCount: 0)
        return .result(dialog: "OK, not marking anything.")
      }
    }

    // Case 4: no match at all -> offer today's remaining pending showups via Siri's
    // native disambiguation UI.
    let candidates = todays.filter { $0.status == "pending" }
    guard !candidates.isEmpty else {
      logResolved(outcome: "abandoned_no_match", candidateCount: 0)
      return .result(dialog: "I couldn't find anything to mark done today.")
    }
    do {
      let chosenName = try await $habitDescription.requestDisambiguation(
        among: candidates.map { $0.habitName },
        dialog: "I couldn't match that to a habit. Which one did you mean?"
      )
      guard let chosen = candidates.first(where: { $0.habitName == chosenName }) else {
        logResolved(outcome: "abandoned_no_match", candidateCount: 0)
        return .result(dialog: "Something went wrong.")
      }
      logResolved(outcome: "recovered_from_no_match", candidateCount: 0)
      return .result(dialog: IntentDialog(stringLiteral: mark(chosen)))
    } catch {
      logResolved(outcome: "abandoned_no_match", candidateCount: 0)
      return .result(dialog: "OK, not marking anything.")
    }
  }

  private func mark(_ showup: VoiceShowup) -> String {
    let ok = VoiceShowupStore.markDone(id: showup.id)
    guard ok else { return "Something went wrong." }
    VoiceNotificationCanceller.cancel(showupId: showup.id)
    VoiceWriteSignal.post()
    Analytics.logEvent("showup_marked_done", parameters: ["pact_id": showup.pactId, "source": "voice"])
    return "Marked \(showup.habitName) done."
  }

  private func logResolved(outcome: String, candidateCount: Int) {
    Analytics.logEvent(
      "voice_mark_done_resolved",
      parameters: ["outcome": outcome, "candidate_count": candidateCount]
    )
  }
}

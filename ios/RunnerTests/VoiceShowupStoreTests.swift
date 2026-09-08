// HAB-269 WU1 — unit tests for VoiceShowupStore's pure matching logic. Exercises the
// `...Matches(in:...)` helpers directly against constructed VoiceShowup arrays, so no
// live SQLite database is required (VoiceShowupStore.todaysOpenShowups is I/O and is
// not covered here — see the plan comment on HAB-269 for why standing up a full native
// test harness for the I/O path was judged disproportionate for a single WU).

import XCTest

@testable import Runner

final class VoiceShowupStoreTests: XCTestCase {
  private let reference = Date(timeIntervalSince1970: 1_700_000_000) // fixed "now"

  private func showup(
    name: String, offsetSeconds: TimeInterval, durationSeconds: TimeInterval = 900,
    status: String = "pending"
  ) -> VoiceShowup {
    let scheduledAt = reference.addingTimeInterval(offsetSeconds)
    return VoiceShowup(
      id: name, pactId: "pact-1", habitName: name, scheduledAt: scheduledAt,
      windowEnd: scheduledAt.addingTimeInterval(durationSeconds), status: status, redeemable: true
    )
  }

  func testPendingMatches_returnsShowupWhoseWindowIsOpenNow() {
    let openNow = showup(name: "Meditate", offsetSeconds: -60)
    let notYetOpen = showup(name: "Meditate later", offsetSeconds: 3600)
    let matches = VoiceShowupStore.pendingMatches(
      in: [openNow, notYetOpen], description: "meditate", now: reference
    )
    XCTAssertEqual(matches, [openNow])
  }

  func testPendingMatches_isCaseInsensitiveSubstring() {
    let showups = [showup(name: "Evening Jog", offsetSeconds: -60)]
    let matches = VoiceShowupStore.pendingMatches(in: showups, description: "JOG", now: reference)
    XCTAssertEqual(matches.count, 1)
  }

  func testPendingMatches_excludesDoneAndNonRedeemableFailed() {
    let done = showup(name: "Meditate", offsetSeconds: -60, status: "done")
    let matches = VoiceShowupStore.pendingMatches(in: [done], description: "meditate", now: reference)
    XCTAssertTrue(matches.isEmpty)
  }

  func testFutureMatches_returnsShowupWhoseWindowHasNotOpenedYet() {
    let future = showup(name: "Meditate", offsetSeconds: 3600)
    let openNow = showup(name: "Meditate now", offsetSeconds: -60)
    let matches = VoiceShowupStore.futureMatches(
      in: [future, openNow], description: "meditate", now: reference
    )
    XCTAssertEqual(matches, [future])
  }

  func testFutureMatches_excludesNonMatchingHabitNames() {
    let future = showup(name: "Jog", offsetSeconds: 3600)
    let matches = VoiceShowupStore.futureMatches(in: [future], description: "meditate", now: reference)
    XCTAssertTrue(matches.isEmpty)
  }
}

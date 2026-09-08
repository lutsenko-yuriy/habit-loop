// HAB-269 WU2 — unit tests for VoicePactBreak.contains, ported literally from
// PactBreak.contains (lib/domain/pact/pact_break.dart) and its own test cases.

import XCTest

@testable import Runner

final class VoicePactBreakTests: XCTestCase {
  private let reference = Date(timeIntervalSince1970: 1_700_000_000) // fixed "now"

  func testContains_falseBeforeStartDate() {
    let b = VoicePactBreak(pactId: "p1", startDate: reference, plannedEndDate: nil, stoppedAt: nil)
    XCTAssertFalse(b.contains(reference.addingTimeInterval(-1)))
  }

  func testContains_openEnded_trueIndefinitelyAfterStart() {
    let b = VoicePactBreak(pactId: "p1", startDate: reference, plannedEndDate: nil, stoppedAt: nil)
    XCTAssertTrue(b.contains(reference.addingTimeInterval(400 * 24 * 3600)))
  }

  func testContains_fixedEnd_trueThroughEndOfPlannedDay() {
    let plannedEnd = reference.addingTimeInterval(3 * 24 * 3600)
    let b = VoicePactBreak(pactId: "p1", startDate: reference, plannedEndDate: plannedEnd, stoppedAt: nil)
    XCTAssertTrue(b.contains(VoicePactBreak.endOfDay(plannedEnd)))
    XCTAssertFalse(b.contains(VoicePactBreak.endOfDay(plannedEnd).addingTimeInterval(1)))
  }

  func testContains_stopped_trueUpToAndIncludingStoppedAt() {
    let stoppedAt = reference.addingTimeInterval(24 * 3600)
    let b = VoicePactBreak(
      pactId: "p1", startDate: reference,
      plannedEndDate: reference.addingTimeInterval(10 * 24 * 3600), stoppedAt: stoppedAt
    )
    XCTAssertTrue(b.contains(stoppedAt))
    XCTAssertFalse(b.contains(stoppedAt.addingTimeInterval(1)))
  }
}

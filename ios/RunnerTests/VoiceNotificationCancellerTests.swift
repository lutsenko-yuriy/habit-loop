// HAB-269 WU2 — golden-value parity tests. These must match
// test/infrastructure/notifications/notification_constants_test.dart's own
// hardcoded expectations exactly — the two formulas (Dart, ported here for
// the native mark-done path) must never drift apart. Do not update either
// side's golden values without scheduling a migration (see the Dart test's
// own comment).

import XCTest

@testable import Runner

final class VoiceNotificationCancellerTests: XCTestCase {
  func testReminderAndDeadlineIds_matchDartGoldenValues() {
    XCTAssertEqual(
      VoiceNotificationCanceller.reminderNotificationId("a1b2c3d4-e5f6-7890-abcd-ef1234567890"), 0x6B3619F
    )
    XCTAssertEqual(
      VoiceNotificationCanceller.deadlineNotificationId("a1b2c3d4-e5f6-7890-abcd-ef1234567890"), 0x46B361A2
    )
    XCTAssertEqual(VoiceNotificationCanceller.reminderNotificationId("showup-id-001"), 0x3E8B1167)
    XCTAssertEqual(VoiceNotificationCanceller.deadlineNotificationId("showup-id-001"), 0x7E8B1168)
  }

  func testHurryUpId_matchesDartGoldenValues() {
    XCTAssertEqual(
      VoiceNotificationCanceller.hurryUpNotificationId("a1b2c3d4-e5f6-7890-abcd-ef1234567890"), -0x6B361A0
    )
    XCTAssertEqual(VoiceNotificationCanceller.hurryUpNotificationId("showup-id-001"), -0x3E8B1168)
  }

  func testIds_areDisjointAndWithinExpectedRanges() {
    let ids = ["a1b2c3d4-e5f6-7890-abcd-ef1234567890", "showup-id-001", "deadbeef-dead-beef-dead-beefdeadbeef"]
    for id in ids {
      let reminderId = VoiceNotificationCanceller.reminderNotificationId(id)
      let deadlineId = VoiceNotificationCanceller.deadlineNotificationId(id)
      let hurryUpId = VoiceNotificationCanceller.hurryUpNotificationId(id)
      XCTAssertLessThan(reminderId, 0x40000000)
      XCTAssertGreaterThanOrEqual(deadlineId, 0x40000000)
      XCTAssertLessThan(hurryUpId, 0)
    }
  }
}

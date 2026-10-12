// GH-464 WU7 — VoiceChecklistGate: the pure decision, plus linkState against an
// in-memory SQLite db using the v8 table shapes from habit_loop_database.dart.

import SQLite3
import XCTest

@testable import Runner

final class VoiceChecklistGateTests: XCTestCase {
  private var db: OpaquePointer?

  override func setUp() {
    super.setUp()
    XCTAssertEqual(sqlite3_open(":memory:", &db), SQLITE_OK)
  }

  override func tearDown() {
    sqlite3_close(db)
    db = nil
    super.tearDown()
  }

  private func exec(_ sql: String) {
    XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, sql)
  }

  private func createV8Tables() {
    exec("""
      CREATE TABLE pact_checklist_links (
        pact_id TEXT NOT NULL PRIMARY KEY, checklist_id TEXT NOT NULL,
        checklist_name TEXT NOT NULL, linked_at INTEGER NOT NULL)
      """)
    exec("""
      CREATE TABLE checklist_runs (
        showup_id TEXT NOT NULL PRIMARY KEY, pact_id TEXT NOT NULL, checklist_id TEXT NOT NULL,
        started_at INTEGER NOT NULL, finished_at INTEGER, outcome TEXT)
      """)
  }

  private func link(pactId: String) {
    exec("INSERT INTO pact_checklist_links VALUES ('\(pactId)', 'c1', 'Morning', 0)")
  }

  private func run(showupId: String, finished: Bool) {
    let finishedAt = finished ? "2000" : "NULL"
    let outcome = finished ? "'completed'" : "NULL"
    exec("INSERT INTO checklist_runs VALUES ('\(showupId)', 'p1', 'c1', 1000, \(finishedAt), \(outcome))")
  }

  // MARK: - isBlocked

  func testIsBlocked_onlyWhenFlagInstalledLinkedAndUnfinished() {
    XCTAssertTrue(VoiceChecklistGate.isBlocked(flagEnabled: true, checklisterInstalled: true, linked: true, runFinished: false))
    XCTAssertFalse(VoiceChecklistGate.isBlocked(flagEnabled: false, checklisterInstalled: true, linked: true, runFinished: false))
    XCTAssertFalse(VoiceChecklistGate.isBlocked(flagEnabled: true, checklisterInstalled: false, linked: true, runFinished: false))
    XCTAssertFalse(VoiceChecklistGate.isBlocked(flagEnabled: true, checklisterInstalled: true, linked: false, runFinished: false))
    XCTAssertFalse(VoiceChecklistGate.isBlocked(flagEnabled: true, checklisterInstalled: true, linked: true, runFinished: true))
  }

  // MARK: - linkState

  func testLinkState_missingTables_readsAsNoLink() {
    let state = VoiceChecklistGate.linkState(db: db!, pactId: "p1", showupId: "s1")
    XCTAssertFalse(state.linked)
    XCTAssertFalse(state.runFinished)
  }

  func testLinkState_otherSqliteError_failsClosed() {
    exec("CREATE TABLE pact_checklist_links (unexpected TEXT)")
    let state = VoiceChecklistGate.linkState(db: db!, pactId: "p1", showupId: "s1")
    XCTAssertTrue(state.linked)
    XCTAssertFalse(state.runFinished)
  }

  func testLinkState_noLinkForPact() {
    createV8Tables()
    link(pactId: "other")
    XCTAssertFalse(VoiceChecklistGate.linkState(db: db!, pactId: "p1", showupId: "s1").linked)
  }

  func testLinkState_linkedWithoutRun_isUnfinished() {
    createV8Tables()
    link(pactId: "p1")
    let state = VoiceChecklistGate.linkState(db: db!, pactId: "p1", showupId: "s1")
    XCTAssertTrue(state.linked)
    XCTAssertFalse(state.runFinished)
  }

  func testLinkState_startedButUnfinishedRun_isUnfinished() {
    createV8Tables()
    link(pactId: "p1")
    run(showupId: "s1", finished: false)
    XCTAssertFalse(VoiceChecklistGate.linkState(db: db!, pactId: "p1", showupId: "s1").runFinished)
  }

  func testLinkState_finishedRun_unlocks() {
    createV8Tables()
    link(pactId: "p1")
    run(showupId: "s1", finished: true)
    XCTAssertTrue(VoiceChecklistGate.linkState(db: db!, pactId: "p1", showupId: "s1").runFinished)
  }

  func testLinkState_finishedRunForAnotherShowup_doesNotUnlock() {
    createV8Tables()
    link(pactId: "p1")
    run(showupId: "s2", finished: true)
    XCTAssertFalse(VoiceChecklistGate.linkState(db: db!, pactId: "p1", showupId: "s1").runFinished)
  }
}

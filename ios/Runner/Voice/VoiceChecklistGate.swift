// GH-464 WU7 — Siri side of the checklist gate, mirroring ChecklistGate.resolve
// (lib/domain/checklist/checklist_gate.dart): voice mark-done refuses a showup whose
// pact has a linked Checklister checklist until an in-app run for it has finished.
// Flag off or Checklister not installed means no gate, same as in-app.

import Foundation
import SQLite3
import UIKit

enum VoiceChecklistGate {
  static let checklisterProbeURL = URL(string: "checklister://")!

  /// Pure — true exactly when ChecklistGate.resolve would return `runRequired`.
  static func isBlocked(flagEnabled: Bool, checklisterInstalled: Bool, linked: Bool, runFinished: Bool) -> Bool {
    flagEnabled && checklisterInstalled && linked && !runFinished
  }

  /// True when voice mark-done must refuse `showup`. Cheapest checks first.
  static func blocks(_ showup: VoiceShowup) async -> Bool {
    guard VoiceFeatureFlag.checklisterIntegrationEnabled else { return false }
    // perform() is deliberately off the main actor; canOpenURL is UIKit.
    let installed = await MainActor.run { UIApplication.shared.canOpenURL(checklisterProbeURL) }
    guard installed, let db = VoiceShowupStore.openConnection() else { return false }
    defer { sqlite3_close(db) }
    let state = linkState(db: db, pactId: showup.pactId, showupId: showup.id)
    return isBlocked(flagEnabled: true, checklisterInstalled: true, linked: state.linked, runFinished: state.runFinished)
  }

  /// Link and run state for one showup. A failed prepare (tables missing before the
  /// v8 migration ran) reads as "no link", so an unmigrated db never blocks.
  static func linkState(db: OpaquePointer, pactId: String, showupId: String) -> (linked: Bool, runFinished: Bool) {
    guard rowExists(db: db, sql: "SELECT 1 FROM pact_checklist_links WHERE pact_id = ?", id: pactId) else {
      return (false, false)
    }
    let finished = rowExists(
      db: db, sql: "SELECT 1 FROM checklist_runs WHERE showup_id = ? AND finished_at IS NOT NULL", id: showupId
    )
    return (true, finished)
  }

  private static func rowExists(db: OpaquePointer, sql: String, id: String) -> Bool {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    defer { sqlite3_finalize(stmt) }
    let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, sqliteTransient)
    return sqlite3_step(stmt) == SQLITE_ROW
  }
}

// HAB-269 WU1 — direct-SQLite data access for the native voice (Siri) layer.
// Reads/writes the exact same habit_loop.db file sqflite manages; no Flutter engine
// involved (a backgrounded AppIntent's perform() runs without booting one). Feasibility
// confirmed during the WU0 checklist — see docs/knowledge/notes/HAB-269.md.
//
// Matching logic is split into pure `...Matches(in:...)` helpers that operate on an
// already-fetched array, separate from the I/O-performing `...Matching(...)` wrappers,
// so RunnerTests can exercise the matching rules without a live database.

import Foundation
import SQLite3

enum VoiceShowupStore {
  /// Mirrors sqflite_darwin's `getDatabasesPath()` — confirmed via its source
  /// (SqflitePlugin.m: `NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, ...)`)
  /// during the WU0 checklist's [agent] pass. Same app sandbox — no App Group needed.
  static var databasePath: String {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("habit_loop.db").path
  }

  /// Today's remaining showups for active pacts, ordered soonest-first.
  /// Filter mirrors PRODUCT_SPEC.md: exclude done, exclude manually-failed
  /// (redeemable = 0), include auto-failed (redeemable = 1) and pending.
  /// Does NOT check pact_breaks — out of scope for this native layer.
  static func todaysOpenShowups(now: Date = Date()) -> [VoiceShowup] {
    var db: OpaquePointer?
    guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
      print("VoiceShowupStore: failed to open db at \(databasePath)")
      return []
    }
    defer { sqlite3_close(db) }

    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: now)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
    let startMs = Int64(startOfDay.timeIntervalSince1970 * 1000)
    let endMs = Int64(endOfDay.timeIntervalSince1970 * 1000)

    let sql = """
      SELECT s.id, p.habit_name, s.scheduled_at, s.duration, s.status, s.redeemable
      FROM showups s
      JOIN pacts p ON p.id = s.pact_id
      WHERE p.status = 'active'
        AND s.scheduled_at >= ? AND s.scheduled_at < ?
        AND s.status != 'done'
        AND (s.status != 'failed' OR s.redeemable = 1)
      ORDER BY s.scheduled_at ASC
      """

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      print("VoiceShowupStore: prepare failed: \(String(cString: sqlite3_errmsg(db)))")
      return []
    }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_int64(stmt, 1, startMs)
    sqlite3_bind_int64(stmt, 2, endMs)

    var results: [VoiceShowup] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      let id = String(cString: sqlite3_column_text(stmt, 0))
      let habitName = String(cString: sqlite3_column_text(stmt, 1))
      let scheduledAtMs = sqlite3_column_int64(stmt, 2)
      // showup_mapper.dart stores Duration.inMicroseconds, not minutes.
      let durationMicroseconds = sqlite3_column_int64(stmt, 3)
      let status = String(cString: sqlite3_column_text(stmt, 4))
      let redeemable = sqlite3_column_int(stmt, 5) == 1

      let scheduledAt = Date(timeIntervalSince1970: Double(scheduledAtMs) / 1000)
      let windowEnd = scheduledAt.addingTimeInterval(Double(durationMicroseconds) / 1_000_000)
      results.append(
        VoiceShowup(
          id: id, habitName: habitName, scheduledAt: scheduledAt,
          windowEnd: windowEnd, status: status, redeemable: redeemable
        )
      )
    }
    return results
  }

  /// Pending showups (window open right now) matching `description` case-insensitively
  /// as a substring of the habit name. Pure — no I/O.
  static func pendingMatches(in showups: [VoiceShowup], description: String, now: Date = Date()) -> [VoiceShowup] {
    showups.filter { showup in
      showup.status == "pending"
        && showup.scheduledAt <= now && now <= showup.windowEnd
        && showup.habitName.localizedCaseInsensitiveContains(description)
    }
  }

  /// Pending-in-the-future showups (window not open yet) matching `description`. Pure — no I/O.
  static func futureMatches(in showups: [VoiceShowup], description: String, now: Date = Date()) -> [VoiceShowup] {
    showups.filter { showup in
      showup.status == "pending"
        && showup.scheduledAt > now
        && showup.habitName.localizedCaseInsensitiveContains(description)
    }
  }

  /// Convenience wrapper: fetches today's showups then applies `pendingMatches`.
  static func pendingMatching(_ description: String, now: Date = Date()) -> [VoiceShowup] {
    pendingMatches(in: todaysOpenShowups(now: now), description: description, now: now)
  }

  /// Convenience wrapper: fetches today's showups then applies `futureMatches`.
  static func futureMatching(_ description: String, now: Date = Date()) -> [VoiceShowup] {
    futureMatches(in: todaysOpenShowups(now: now), description: description, now: now)
  }

  /// Raw UPDATE, threaded through the same `dirty`/`synced_at` convention
  /// ShowupMapper.toRow() uses so the write queues for the next sync pass.
  @discardableResult
  static func markDone(id: String) -> Bool {
    var db: OpaquePointer?
    guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
      return false
    }
    defer { sqlite3_close(db) }

    let sql = "UPDATE showups SET status = 'done', dirty = 1, synced_at = NULL WHERE id = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
    return sqlite3_step(stmt) == SQLITE_DONE
  }
}

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

  // HabitLoopDatabase._open() sets `PRAGMA journal_mode=WAL` persistently, and a
  // read-only connection can fail to read a WAL db that needs -shm initialised or a
  // -wal replay (exactly the cold, app-not-running case this feature targets — audit
  // finding, HAB-269 WU1 review). Open read-write even for reads; the sandbox already
  // grants this process write access to its own habit_loop.db.
  private static func openConnection() -> OpaquePointer? {
    var db: OpaquePointer?
    guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
      print("VoiceShowupStore: failed to open db at \(databasePath)")
      // sqlite3_open_v2 can allocate a handle even on failure (per SQLite docs) — close
      // it instead of leaking (HAB-269 WU2 fast-follow; caught in WU1's own post-fix audit).
      sqlite3_close(db)
      return nil
    }
    // A live backgrounded app can be mid-write and briefly hold the WAL lock — retry
    // for up to 3s instead of failing the very first contended access.
    sqlite3_busy_timeout(db, 3000)
    return db
  }

  /// Today's remaining showups for active pacts, ordered soonest-first.
  /// Filter mirrors PRODUCT_SPEC.md: exclude done, exclude manually-failed
  /// (redeemable = 0), include auto-failed (redeemable = 1) and pending.
  /// Does NOT check pact_breaks — out of scope for this native layer (HAB-269 WU1);
  /// must be closed before WU2 flips voice_mark_done_enabled — see docs/knowledge/notes/HAB-269.md.
  static func todaysOpenShowups(now: Date = Date()) -> [VoiceShowup] {
    guard let db = openConnection() else { return [] }
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
  /// `AND status = 'pending'` guards against a race where the showup was manually
  /// failed in-app during Siri's confirmation round-trip — a stale "done" report to
  /// the user is safer than silently overwriting that fail. `sqlite3_changes` (not
  /// just SQLITE_DONE, which is also returned for a zero-row match) is what actually
  /// confirms the row was updated.
  @discardableResult
  static func markDone(id: String) -> Bool {
    guard let db = openConnection() else { return false }
    defer { sqlite3_close(db) }

    let sql = "UPDATE showups SET status = 'done', dirty = 1, synced_at = NULL WHERE id = ? AND status = 'pending'"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    defer { sqlite3_finalize(stmt) }

    // nil destructor here would be SQLITE_STATIC, binding NSString's transient inner
    // buffer past its lifetime; SQLITE_TRANSIENT makes sqlite3 copy the bytes instead.
    let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, sqliteTransient)
    guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
    return sqlite3_changes(db) > 0
  }
}

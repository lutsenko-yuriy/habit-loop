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
  /// Also excludes (HAB-269 WU2, closing WU1's must-close gaps):
  /// - any pending showup covered by an unresolved-or-resolved break window
  ///   (mirrors BreakDerivation.isShowupOnBreak / showup_detail_content.dart's
  ///   HAB-213 rule that hides Mark Done for on-break showups);
  /// - any showup whose window has already closed (`windowEnd < now`) — a
  ///   stale, not-yet-reconciled showup must not read back as "remaining".
  static func todaysOpenShowups(now: Date = Date()) -> [VoiceShowup] {
    guard let db = openConnection() else { return [] }
    defer { sqlite3_close(db) }

    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: now)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
    let startMs = Int64(startOfDay.timeIntervalSince1970 * 1000)
    let endMs = Int64(endOfDay.timeIntervalSince1970 * 1000)

    let sql = """
      SELECT s.id, s.pact_id, p.habit_name, s.scheduled_at, s.duration, s.status, s.redeemable
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

    var rows: [VoiceShowup] = []
    var pactIds: Set<String> = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      let id = String(cString: sqlite3_column_text(stmt, 0))
      let pactId = String(cString: sqlite3_column_text(stmt, 1))
      let habitName = String(cString: sqlite3_column_text(stmt, 2))
      let scheduledAtMs = sqlite3_column_int64(stmt, 3)
      // showup_mapper.dart stores Duration.inMicroseconds, not minutes.
      let durationMicroseconds = sqlite3_column_int64(stmt, 4)
      let status = String(cString: sqlite3_column_text(stmt, 5))
      let redeemable = sqlite3_column_int(stmt, 6) == 1

      let scheduledAt = Date(timeIntervalSince1970: Double(scheduledAtMs) / 1000)
      let windowEnd = scheduledAt.addingTimeInterval(Double(durationMicroseconds) / 1_000_000)
      rows.append(
        VoiceShowup(
          id: id, pactId: pactId, habitName: habitName, scheduledAt: scheduledAt,
          windowEnd: windowEnd, status: status, redeemable: redeemable
        )
      )
      pactIds.insert(pactId)
    }

    let breaksByPactId = fetchBreaks(db: db, pactIds: pactIds)
    return rows.compactMap { showup in
      if showup.windowEnd < now { return nil }
      if showup.status == "pending" {
        let breaks = breaksByPactId[showup.pactId] ?? []
        if breaks.contains(where: { $0.contains(showup.scheduledAt) }) { return nil }
      }
      return showup
    }
  }

  /// Fetches every break for the given pact ids, keyed by pact id. A single
  /// query (rather than one per pact) since `pactIds` is at most the handful
  /// of active pacts with a showup today.
  private static func fetchBreaks(db: OpaquePointer, pactIds: Set<String>) -> [String: [VoicePactBreak]] {
    guard !pactIds.isEmpty else { return [:] }

    let placeholders = pactIds.map { _ in "?" }.joined(separator: ", ")
    let sql = "SELECT pact_id, start_date, planned_end_date, stopped_at FROM pact_breaks WHERE pact_id IN (\(placeholders))"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      print("VoiceShowupStore: fetchBreaks prepare failed: \(String(cString: sqlite3_errmsg(db)))")
      return [:]
    }
    defer { sqlite3_finalize(stmt) }

    let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    for (index, pactId) in pactIds.enumerated() {
      sqlite3_bind_text(stmt, Int32(index + 1), (pactId as NSString).utf8String, -1, sqliteTransient)
    }

    var result: [String: [VoicePactBreak]] = [:]
    while sqlite3_step(stmt) == SQLITE_ROW {
      let pactId = String(cString: sqlite3_column_text(stmt, 0))
      let startDate = Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 1)) / 1000)
      let plannedEndDate = sqlite3_column_type(stmt, 2) == SQLITE_NULL
        ? nil : Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 2)) / 1000)
      let stoppedAt = sqlite3_column_type(stmt, 3) == SQLITE_NULL
        ? nil : Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 3)) / 1000)
      let voiceBreak = VoicePactBreak(
        pactId: pactId, startDate: startDate, plannedEndDate: plannedEndDate, stoppedAt: stoppedAt
      )
      result[pactId, default: []].append(voiceBreak)
    }
    return result
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

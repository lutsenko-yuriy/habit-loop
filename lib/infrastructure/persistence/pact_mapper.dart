import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/persistence/schedule_codec.dart';

/// Maps [Pact] domain objects to and from SQLite row maps.
///
/// The canonical column-to-field mapping is defined by [toRow] and [fromRow].
/// Schema DDL lives in `HabitLoopDatabase.runMigrations`.
///
/// `PactStats` is **not** persisted — it is always computed from SQL aggregates
/// at read time. [fromRow] therefore always returns a [Pact] with `stats: null`.
abstract final class PactMapper {
  /// Converts [pact] to a column map ready for SQLite insertion or update.
  ///
  /// `total_showups` is written as `null` by this method — it is set by
  /// `savePactWithShowups()` which has access to the full showup count.
  ///
  /// `actual_end_date` is initialised to `scheduled_end_date` here; the
  /// stop-pact transaction overwrites it to the actual stop date.
  ///
  /// **`scheduled_end_date` is immutable after initial insert.**
  /// It must never be updated via this method in a subsequent `UPDATE` statement.
  /// The stop-pact transaction (WU3) must update `actual_end_date` directly:
  /// ```sql
  /// UPDATE pacts SET actual_end_date = ? WHERE id = ?
  /// ```
  /// Going through `PactMapper.toRow` in the stop-pact path would overwrite
  /// `scheduled_end_date` with the stop date, breaking the invariant that
  /// `scheduled_end_date` always holds the original planned end date.
  static Map<String, dynamic> toRow(Pact pact) {
    return {
      'id': pact.id,
      'habit_name': pact.habitName,
      'start_date': pact.startDate.millisecondsSinceEpoch,
      'scheduled_end_date': pact.endDate.millisecondsSinceEpoch,
      'actual_end_date': pact.endDate.millisecondsSinceEpoch,
      'showup_duration': pact.showupDuration.inMicroseconds,
      'schedule': ScheduleCodec.encode(pact.schedule),
      'status': _encodeStatus(pact.status),
      'reminder_offset': pact.reminderOffset?.inMicroseconds,
      'stop_reason': pact.stopReason,
      'created_at': pact.createdAt?.millisecondsSinceEpoch,
      'total_showups': null,
    };
  }

  /// Reconstructs a [Pact] from a SQLite row map.
  ///
  /// Always returns a [Pact] with `stats: null` — stats are computed from SQL
  /// aggregates, not stored in a column.
  ///
  /// All [DateTime] fields are reconstructed as **local-time** values, matching
  /// the local-time [DateTime] objects produced by [PactBuilder] (which
  /// normalises `startDate` to local midnight). Using `isUtc: true` would silently
  /// shift timestamps in non-UTC timezones, causing [ShowupGenerator]'s date
  /// iteration to produce off-by-timezone-offset boundary errors.
  ///
  /// `total_showups` may be `null` for legacy rows or rows written before the
  /// first `savePactWithShowups()` call; this is handled gracefully.
  ///
  /// Throws [ArgumentError] if the `status` column contains an unknown value.
  static Pact fromRow(Map<String, dynamic> row) {
    return Pact(
      id: row['id'] as String,
      habitName: row['habit_name'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(
        (row['start_date'] as num).toInt(),
      ),
      endDate: DateTime.fromMillisecondsSinceEpoch(
        (row['scheduled_end_date'] as num).toInt(),
      ),
      showupDuration: Duration(microseconds: (row['showup_duration'] as num).toInt()),
      schedule: ScheduleCodec.decode(row['schedule'] as String),
      status: _decodeStatus(row['status'] as String),
      reminderOffset:
          row['reminder_offset'] != null ? Duration(microseconds: (row['reminder_offset'] as num).toInt()) : null,
      stopReason: row['stop_reason'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (row['created_at'] as num).toInt(),
            )
          : null,
      // total_showups is read-acknowledged but not propagated into the domain
      // model; it lives in the DB column only and is consumed by stats queries.
      stats: null,
    );
  }

  /// Returns only the columns that may legitimately change after a pact is
  /// created — for use by [SqlitePactRepository.updatePact].
  ///
  /// The following columns are intentionally **excluded** because they are
  /// immutable after initial insert and must never be overwritten:
  /// - `id`, `start_date`, `scheduled_end_date`, `showup_duration`, `schedule`,
  ///   `created_at` — structural / historical facts
  /// - `total_showups` — set by `savePactWithShowups()` (WU3); overwriting it
  ///   here would null it out and break pact stats
  ///
  /// The following mutable columns ARE included:
  /// - `habit_name` — user may rename (future feature)
  /// - `status` — transitions active → stopped / completed
  /// - `actual_end_date` — updated to the stop date when a pact is stopped
  /// - `reminder_offset` — may be changed in settings (future feature)
  /// - `stop_reason` — written when the user stops a pact
  static Map<String, dynamic> toUpdateRow(Pact pact) {
    return {
      'habit_name': pact.habitName,
      'status': _encodeStatus(pact.status),
      'actual_end_date': pact.endDate.millisecondsSinceEpoch,
      'reminder_offset': pact.reminderOffset?.inMicroseconds,
      'stop_reason': pact.stopReason,
    };
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static String _encodeStatus(PactStatus status) => switch (status) {
        PactStatus.active => 'active',
        PactStatus.stopped => 'stopped',
        PactStatus.completed => 'completed',
      };

  static PactStatus _decodeStatus(String value) => switch (value) {
        'active' => PactStatus.active,
        'stopped' => PactStatus.stopped,
        'completed' => PactStatus.completed,
        _ => throw ArgumentError.value(value, 'status', 'Unknown PactStatus value'),
      };
}

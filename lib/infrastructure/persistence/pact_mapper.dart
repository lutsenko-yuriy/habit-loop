import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/persistence/schedule_codec.dart';

/// Maps [Pact] domain objects to and from SQLite row maps.
///
/// Column layout (schema v1):
///
/// ```sql
/// id                 TEXT    NOT NULL PRIMARY KEY
/// habit_name         TEXT    NOT NULL
/// start_date         INTEGER NOT NULL   -- ms since epoch
/// scheduled_end_date INTEGER NOT NULL   -- ms since epoch (immutable)
/// actual_end_date    INTEGER NOT NULL   -- ms since epoch; = scheduled_end_date, or stop date if stopped
/// showup_duration    INTEGER NOT NULL   -- microseconds
/// schedule           TEXT    NOT NULL   -- JSON discriminated union
/// status             TEXT    NOT NULL   -- 'active' | 'stopped' | 'completed'
/// reminder_offset    INTEGER            -- microseconds, NULL = no reminder
/// stop_reason        TEXT
/// created_at         INTEGER            -- ms since epoch, NULL for legacy rows
/// total_showups      INTEGER            -- written once at creation by savePactWithShowups, never changed
/// ```
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
        isUtc: true,
      ),
      endDate: DateTime.fromMillisecondsSinceEpoch(
        (row['scheduled_end_date'] as num).toInt(),
        isUtc: true,
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
              isUtc: true,
            )
          : null,
      // total_showups is read-acknowledged but not propagated into the domain
      // model; it lives in the DB column only and is consumed by stats queries.
      stats: null,
    );
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

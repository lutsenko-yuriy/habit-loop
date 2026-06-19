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
  /// `scheduled_end_date` is immutable after initial insert — never call [toRow]
  /// in an UPDATE statement or it will overwrite the original planned end date.
  /// The stop-pact transaction updates `actual_end_date` directly instead.
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
      // Every insert starts dirty=1 — queued for the first sync flush.
      'dirty': 1,
      'synced_at': null,
      'archived': pact.archived ? 1 : 0,
    };
  }

  /// [DateTime] fields are local-time, not UTC — using `isUtc: true` would
  /// silently shift timestamps and break ShowupGenerator's date iteration.
  static Pact fromRow(Map<String, dynamic> row) {
    final status = _decodeStatus(row['status'] as String);
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
      status: status,
      reminderOffset:
          row['reminder_offset'] != null ? Duration(microseconds: (row['reminder_offset'] as num).toInt()) : null,
      stopReason: row['stop_reason'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (row['created_at'] as num).toInt(),
            )
          : null,
      // For stopped pacts, read actual_end_date back as stoppedAt so the UI
      // can show both the actual stop date and the original scheduled end date.
      stoppedAt: status == PactStatus.stopped && row['actual_end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch((row['actual_end_date'] as num).toInt())
          : null,
      // total_showups is read-acknowledged but not propagated into the domain
      // model; it lives in the DB column only and is consumed by stats queries.
      // dirty and synced_at live only in the sync layer — not on the domain model.
      // archived absent means the row predates v3 — treat as false.
      archived: (row['archived'] as int? ?? 0) == 1,
      stats: null,
    );
  }

  /// Mutable-only columns for UPDATE — excludes immutable structural fields
  /// (`id`, `start_date`, `scheduled_end_date`, `showup_duration`, `schedule`,
  /// `created_at`, `total_showups`) that must never be overwritten after insert.
  static Map<String, dynamic> toUpdateRow(Pact pact) {
    return {
      'habit_name': pact.habitName,
      'status': _encodeStatus(pact.status),
      // For stopped pacts, actual_end_date holds the real stop date; for all
      // others it mirrors scheduled_end_date (no effective change).
      'actual_end_date': (pact.stoppedAt ?? pact.endDate).millisecondsSinceEpoch,
      'reminder_offset': pact.reminderOffset?.inMicroseconds,
      'stop_reason': pact.stopReason,
      // Every update re-marks the record dirty — the sync layer will re-upload it.
      'dirty': 1,
      'archived': pact.archived ? 1 : 0,
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

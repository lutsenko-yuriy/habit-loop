import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

/// Maps [Showup] domain objects to and from SQLite row maps.
///
/// The canonical column-to-field mapping is defined by [toRow] and [fromRow].
/// Schema DDL lives in `HabitLoopDatabase.runMigrations`.
abstract final class ShowupMapper {
  /// Converts [showup] to a column map ready for SQLite insertion or update.
  static Map<String, dynamic> toRow(Showup showup) {
    return {
      'id': showup.id,
      'pact_id': showup.pactId,
      'scheduled_at': showup.scheduledAt.millisecondsSinceEpoch,
      'duration': showup.duration.inMicroseconds,
      'status': _encodeStatus(showup.status),
      'note': showup.note,
    };
  }

  /// Reconstructs a [Showup] from a SQLite row map.
  ///
  /// `scheduled_at` is restored as a **local-time** [DateTime], matching the
  /// local-time values produced by [ShowupGenerator._combine]. Using `isUtc: true`
  /// here would silently shift times in non-UTC timezones (e.g. UTC+2 would
  /// reconstruct 8:00 AM as 6:00 AM).
  ///
  /// Throws [ArgumentError] if the `status` column contains an unknown value.
  static Showup fromRow(Map<String, dynamic> row) {
    return Showup(
      id: row['id'] as String,
      pactId: row['pact_id'] as String,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        (row['scheduled_at'] as num).toInt(),
      ),
      duration: Duration(microseconds: (row['duration'] as num).toInt()),
      status: _decodeStatus(row['status'] as String),
      note: row['note'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static String _encodeStatus(ShowupStatus status) => switch (status) {
        ShowupStatus.pending => 'pending',
        ShowupStatus.done => 'done',
        ShowupStatus.failed => 'failed',
      };

  static ShowupStatus _decodeStatus(String value) => switch (value) {
        'pending' => ShowupStatus.pending,
        'done' => ShowupStatus.done,
        'failed' => ShowupStatus.failed,
        _ => throw ArgumentError.value(value, 'status', 'Unknown ShowupStatus value'),
      };
}

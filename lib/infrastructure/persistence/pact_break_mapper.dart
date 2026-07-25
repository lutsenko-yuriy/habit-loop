import 'package:habit_loop/domain/pact/pact_break.dart';

/// Maps [PactBreak] domain objects to and from SQLite row maps.
///
/// The canonical column-to-field mapping is defined by [toRow] and [fromRow].
/// Schema DDL lives in `HabitLoopDatabase.runMigrations`.
abstract final class PactBreakMapper {
  /// Converts [pactBreak] to a column map ready for SQLite insertion or update.
  static Map<String, dynamic> toRow(PactBreak pactBreak) {
    return {
      'id': pactBreak.id,
      'pact_id': pactBreak.pactId,
      'start_date': pactBreak.startDate.millisecondsSinceEpoch,
      'rationale': pactBreak.rationale,
      'planned_end_date': pactBreak.plannedEndDate?.millisecondsSinceEpoch,
      'created_at': pactBreak.createdAt?.millisecondsSinceEpoch,
      'stopped_at': pactBreak.stoppedAt?.millisecondsSinceEpoch,
      // Every insert/update starts dirty=1 — queued for the first sync flush.
      'dirty': 1,
      'synced_at': null,
    };
  }

  /// Reconstructs a [PactBreak] from a SQLite row map.
  ///
  /// Dates are restored as **local-time** [DateTime]s, matching the
  /// local-time convention used by [ShowupMapper] — using `isUtc: true` here
  /// would silently shift times in non-UTC timezones.
  static PactBreak fromRow(Map<String, dynamic> row) {
    return PactBreak(
      id: row['id'] as String,
      pactId: row['pact_id'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch((row['start_date'] as num).toInt()),
      rationale: row['rationale'] as String,
      plannedEndDate: row['planned_end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch((row['planned_end_date'] as num).toInt())
          : null,
      createdAt:
          row['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch((row['created_at'] as num).toInt()) : null,
      stoppedAt:
          row['stopped_at'] != null ? DateTime.fromMillisecondsSinceEpoch((row['stopped_at'] as num).toInt()) : null,
      // dirty and synced_at live only in the sync layer — not on the domain model.
    );
  }
}

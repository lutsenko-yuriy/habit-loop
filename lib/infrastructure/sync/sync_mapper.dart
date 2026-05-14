import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/persistence/schedule_codec.dart';

/// Encodes domain objects to Firestore document maps and decodes them back.
///
/// Deliberately excludes sync-only columns (`dirty`, `synced_at`) and the
/// SQLite-specific `total_showups` denormalized column so the Firestore
/// document contains only clean domain data.
///
/// The `updated_at` field is included in every document so that WU5
/// pull-on-start can compare remote vs local timestamps for merge decisions.
abstract final class SyncMapper {
  /// Encodes [pact] to a Firestore document map.
  ///
  /// [updatedAt] is written as `updated_at` (epoch ms). Defaults to
  /// [DateTime.now] when not supplied so existing callers need no changes.
  static Map<String, dynamic> pactToDocument(Pact pact, {DateTime? updatedAt}) {
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
      'updated_at': (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }

  /// Encodes [showup] to a Firestore document map.
  ///
  /// [updatedAt] is written as `updated_at` (epoch ms). Defaults to
  /// [DateTime.now] when not supplied.
  static Map<String, dynamic> showupToDocument(Showup showup, {DateTime? updatedAt}) {
    return {
      'id': showup.id,
      'pact_id': showup.pactId,
      'scheduled_at': showup.scheduledAt.millisecondsSinceEpoch,
      'duration': showup.duration.inMicroseconds,
      'status': _encodeShowupStatus(showup.status),
      'note': showup.note,
      'updated_at': (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }

  /// Decodes a Firestore document map back into a [Pact].
  ///
  /// All [DateTime] fields are reconstructed as **local-time** values,
  /// matching the convention used by [PactMapper.fromRow].
  ///
  /// `updated_at` is NOT propagated to the domain model; callers that need
  /// the remote timestamp should call [updatedAtFromDocument] separately.
  ///
  /// Throws if any required field is absent or has an unexpected type/value
  /// (e.g. unknown `status` string). Callers that want error isolation should
  /// wrap in try-catch.
  static Pact pactFromDocument(Map<String, dynamic> doc) {
    return Pact(
      id: doc['id'] as String,
      habitName: doc['habit_name'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(
        (doc['start_date'] as num).toInt(),
      ),
      endDate: DateTime.fromMillisecondsSinceEpoch(
        (doc['scheduled_end_date'] as num).toInt(),
      ),
      showupDuration: Duration(microseconds: (doc['showup_duration'] as num).toInt()),
      schedule: ScheduleCodec.decode(doc['schedule'] as String),
      status: _decodeStatus(doc['status'] as String),
      reminderOffset:
          doc['reminder_offset'] != null ? Duration(microseconds: (doc['reminder_offset'] as num).toInt()) : null,
      stopReason: doc['stop_reason'] as String?,
      createdAt:
          doc['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch((doc['created_at'] as num).toInt()) : null,
    );
  }

  /// Decodes a Firestore document map back into a [Showup].
  ///
  /// All [DateTime] fields are reconstructed as **local-time** values.
  ///
  /// `updated_at` is NOT propagated to the domain model; use
  /// [updatedAtFromDocument] separately.
  ///
  /// Throws if any required field is absent or has an unexpected type/value.
  static Showup showupFromDocument(Map<String, dynamic> doc) {
    return Showup(
      id: doc['id'] as String,
      pactId: doc['pact_id'] as String,
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        (doc['scheduled_at'] as num).toInt(),
      ),
      duration: Duration(microseconds: (doc['duration'] as num).toInt()),
      status: _decodeShowupStatus(doc['status'] as String),
      note: doc['note'] as String?,
    );
  }

  /// Extracts the `updated_at` timestamp from a Firestore document map.
  ///
  /// Returns `null` when the field is absent or null (e.g. documents written
  /// before WU5 was deployed).
  static DateTime? updatedAtFromDocument(Map<String, dynamic> doc) {
    final ms = doc['updated_at'];
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
  }

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

  static String _encodeShowupStatus(ShowupStatus status) => switch (status) {
        ShowupStatus.pending => 'pending',
        ShowupStatus.done => 'done',
        ShowupStatus.failed => 'failed',
      };

  static ShowupStatus _decodeShowupStatus(String value) => switch (value) {
        'pending' => ShowupStatus.pending,
        'done' => ShowupStatus.done,
        'failed' => ShowupStatus.failed,
        _ => throw ArgumentError.value(value, 'status', 'Unknown ShowupStatus value'),
      };
}

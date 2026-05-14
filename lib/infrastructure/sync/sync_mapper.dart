import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/persistence/schedule_codec.dart';

/// Encodes domain objects to Firestore document maps.
///
/// Deliberately excludes sync-only columns (`dirty`, `synced_at`) and the
/// SQLite-specific `total_showups` denormalized column so the Firestore
/// document contains only clean domain data.
abstract final class SyncMapper {
  /// Encodes [pact] to a Firestore document map.
  static Map<String, dynamic> pactToDocument(Pact pact) {
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
    };
  }

  /// Encodes [showup] to a Firestore document map.
  static Map<String, dynamic> showupToDocument(Showup showup) {
    return {
      'id': showup.id,
      'pact_id': showup.pactId,
      'scheduled_at': showup.scheduledAt.millisecondsSinceEpoch,
      'duration': showup.duration.inMicroseconds,
      'status': _encodeShowupStatus(showup.status),
      'note': showup.note,
    };
  }

  static String _encodeStatus(PactStatus status) => switch (status) {
        PactStatus.active => 'active',
        PactStatus.stopped => 'stopped',
        PactStatus.completed => 'completed',
      };

  static String _encodeShowupStatus(ShowupStatus status) => switch (status) {
        ShowupStatus.pending => 'pending',
        ShowupStatus.done => 'done',
        ShowupStatus.failed => 'failed',
      };
}

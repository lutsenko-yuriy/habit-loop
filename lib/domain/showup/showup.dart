import 'package:habit_loop/domain/showup/showup_status.dart';

class Showup {
  final String id;
  final String pactId;
  final DateTime scheduledAt;
  final Duration duration;
  final ShowupStatus status;
  final String? note;

  /// True when the local state has not yet been flushed to Firestore.
  ///
  /// Defaults to `true` so every newly created showup is queued for sync.
  /// Set to `false` (alongside [syncedAt]) by the sync layer after a
  /// successful Firestore write.
  final bool dirty;

  /// The wall-clock instant of the last successful Firestore sync, or `null`
  /// if this showup has never been synced.
  final DateTime? syncedAt;

  const Showup({
    required this.id,
    required this.pactId,
    required this.scheduledAt,
    required this.duration,
    required this.status,
    this.note,
    this.dirty = true,
    this.syncedAt,
  });

  /// Returns a copy of this showup with the given fields replaced.
  ///
  /// [id], [pactId], [scheduledAt], and [duration] are immutable and cannot
  /// be changed after creation — they form the identity of a showup.
  Showup copyWith({
    ShowupStatus? status,
    String? note,
    bool? dirty,
    DateTime? syncedAt,
    bool clearNote = false,
    bool clearSyncedAt = false,
  }) {
    return Showup(
      id: id,
      pactId: pactId,
      scheduledAt: scheduledAt,
      duration: duration,
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      dirty: dirty ?? this.dirty,
      syncedAt: clearSyncedAt ? null : (syncedAt ?? this.syncedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Showup &&
          id == other.id &&
          pactId == other.pactId &&
          scheduledAt == other.scheduledAt &&
          duration == other.duration &&
          status == other.status &&
          note == other.note &&
          dirty == other.dirty &&
          syncedAt == other.syncedAt;

  @override
  int get hashCode => Object.hash(
        id,
        pactId,
        scheduledAt,
        duration,
        status,
        note,
        dirty,
        syncedAt,
      );
}

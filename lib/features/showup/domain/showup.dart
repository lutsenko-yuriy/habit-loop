import 'package:habit_loop/features/showup/domain/showup_status.dart';

class Showup {
  final String id;
  final String pactId;
  final DateTime scheduledAt;
  final Duration duration;
  final ShowupStatus status;
  final String? note;

  const Showup({
    required this.id,
    required this.pactId,
    required this.scheduledAt,
    required this.duration,
    required this.status,
    this.note,
  });

  /// Returns a copy of this showup with the given fields replaced.
  ///
  /// [id], [pactId], and [scheduledAt] are immutable and cannot be changed
  /// after creation — they form the identity of a showup.
  Showup copyWith({
    ShowupStatus? status,
    String? note,
    bool clearNote = false,
  }) {
    return Showup(
      id: id,
      pactId: pactId,
      scheduledAt: scheduledAt,
      duration: duration,
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
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
          note == other.note;

  @override
  int get hashCode => Object.hash(
        id,
        pactId,
        scheduledAt,
        duration,
        status,
        note,
      );
}

import 'package:habit_loop/domain/showup/showup_status.dart';

class Showup {
  final String id;
  final String pactId;
  final DateTime scheduledAt;
  final Duration duration;
  final ShowupStatus status;
  final String? note;
  final bool redeemable;

  const Showup({
    required this.id,
    required this.pactId,
    required this.scheduledAt,
    required this.duration,
    required this.status,
    this.note,
    this.redeemable = true,
  });

  // id, pactId, scheduledAt, and duration are immutable — they form the identity of a showup.
  Showup copyWith({
    ShowupStatus? status,
    String? note,
    bool clearNote = false,
    bool? redeemable,
  }) {
    return Showup(
      id: id,
      pactId: pactId,
      scheduledAt: scheduledAt,
      duration: duration,
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      redeemable: redeemable ?? this.redeemable,
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
          redeemable == other.redeemable;

  @override
  int get hashCode => Object.hash(id, pactId, scheduledAt, duration, status, note, redeemable);
}

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

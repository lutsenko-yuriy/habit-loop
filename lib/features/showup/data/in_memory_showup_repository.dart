import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';

class InMemoryShowupRepository implements ShowupRepository {
  final List<Showup> _showups;

  InMemoryShowupRepository([List<Showup>? showups])
      : _showups = showups ?? [];

  @override
  Future<List<Showup>> getShowupsForDate(DateTime date) async {
    return _showups.where((s) {
      return s.scheduledAt.year == date.year &&
          s.scheduledAt.month == date.month &&
          s.scheduledAt.day == date.day;
    }).toList();
  }

  @override
  Future<List<Showup>> getShowupsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return _showups.where((s) {
      return !s.scheduledAt.isBefore(startDate) &&
          !s.scheduledAt.isAfter(endDate);
    }).toList();
  }
}

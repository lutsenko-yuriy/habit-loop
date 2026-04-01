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

  @override
  Future<Showup?> getShowupById(String id) async {
    try {
      return _showups.firstWhere((s) => s.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    return _showups.where((s) => s.pactId == pactId).toList();
  }

  @override
  Future<void> saveShowup(Showup showup) async {
    _showups.add(showup);
  }

  @override
  Future<void> saveShowups(List<Showup> showups) async {
    _showups.addAll(showups);
  }

  @override
  Future<void> updateShowup(Showup showup) async {
    final index = _showups.indexWhere((s) => s.id == showup.id);
    if (index == -1) {
      throw ArgumentError('Showup with id "${showup.id}" not found.');
    }
    _showups[index] = showup;
  }
}

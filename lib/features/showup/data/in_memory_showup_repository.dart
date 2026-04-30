import 'package:habit_loop/domain/showup/save_showups_result.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_date_utils.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';

class InMemoryShowupRepository implements ShowupRepository {
  final List<Showup> _showups;

  InMemoryShowupRepository([List<Showup>? showups]) : _showups = showups != null ? List.of(showups) : [];

  @override
  Future<List<Showup>> getShowupsForDate(DateTime date) async {
    return _showups.where((s) {
      return s.scheduledAt.year == date.year && s.scheduledAt.month == date.month && s.scheduledAt.day == date.day;
    }).toList();
  }

  @override
  Future<List<Showup>> getShowupsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final startDay = ShowupDateUtils.startOfDay(start);
    final endDay = ShowupDateUtils.endOfDay(end);
    return _showups.where((s) {
      return !s.scheduledAt.isBefore(startDay) && s.scheduledAt.isBefore(endDay);
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
    if (_showups.any((s) => s.id == showup.id)) {
      throw ArgumentError('Showup with id "${showup.id}" already exists.');
    }
    _showups.add(showup);
  }

  @override
  Future<SaveShowupsResult> saveShowups(List<Showup> showups) async {
    final existingIds = _showups.map((s) => s.id).toSet();
    final skippedIds = <String>[];
    var savedCount = 0;

    for (final showup in showups) {
      if (existingIds.contains(showup.id)) {
        skippedIds.add(showup.id);
      } else {
        _showups.add(showup);
        existingIds.add(showup.id);
        savedCount++;
      }
    }

    return SaveShowupsResult(savedCount: savedCount, skippedIds: skippedIds);
  }

  @override
  Future<void> updateShowup(Showup showup) async {
    final index = _showups.indexWhere((s) => s.id == showup.id);
    if (index == -1) {
      throw ArgumentError('Showup with id "${showup.id}" not found.');
    }
    _showups[index] = showup;
  }

  @override
  Future<int> countShowupsForPact(String pactId) async {
    return _showups.where((s) => s.pactId == pactId).length;
  }

  @override
  Future<void> deleteShowupsForPact(String pactId) async {
    _showups.removeWhere((s) => s.pactId == pactId);
  }
}

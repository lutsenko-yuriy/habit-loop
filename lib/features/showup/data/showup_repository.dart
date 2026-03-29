import 'package:habit_loop/features/showup/domain/showup.dart';

abstract class ShowupRepository {
  Future<List<Showup>> getShowupsForDate(DateTime date);
  Future<List<Showup>> getShowupsForDateRange(DateTime start, DateTime end);
}

import 'package:habit_loop/features/showup/domain/showup.dart';

abstract class ShowupRepository {
  Future<List<Showup>> getShowupsForDate(DateTime date);
  Future<List<Showup>> getShowupsForDateRange(DateTime start, DateTime end);
  Future<Showup?> getShowupById(String id);
  Future<List<Showup>> getShowupsForPact(String pactId);
  Future<void> saveShowup(Showup showup);
  Future<void> saveShowups(List<Showup> showups);
  Future<void> updateShowup(Showup showup);
}

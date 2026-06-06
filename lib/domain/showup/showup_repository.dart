import 'package:habit_loop/domain/showup/save_showups_result.dart';
import 'package:habit_loop/domain/showup/showup.dart';

/// Cascade: when a Pact is deleted, the caller must also delete its showups.
abstract class ShowupRepository {
  Future<List<Showup>> getShowupsForDate(DateTime date);
  Future<List<Showup>> getShowupsForDateRange(DateTime start, DateTime end);
  Future<Showup?> getShowupById(String id);
  Future<List<Showup>> getShowupsForPact(String pactId);

  /// Persists a single showup.
  ///
  /// Throws [ArgumentError] if a showup with the same id already exists.
  Future<void> saveShowup(Showup showup);

  /// Skips showups whose ids already exist. Returns saved/skipped counts.
  /// Atomic: either all new showups are written or none are.
  Future<SaveShowupsResult> saveShowups(List<Showup> showups);

  /// Updates an existing showup by id.
  ///
  /// Throws [ArgumentError] if no showup with the given id exists.
  Future<void> updateShowup(Showup showup);

  /// Used by DashboardViewModel to detect absence gaps (extended periods without opening the app).
  Future<DateTime?> getLatestScheduledAtForPact(String pactId);

  Future<int> countShowupsForPact(String pactId);

  /// Atomic: either all showups for the pact are deleted or none are.
  Future<void> deleteShowupsForPact(String pactId);
}

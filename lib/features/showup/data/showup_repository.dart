import 'package:habit_loop/features/showup/domain/save_showups_result.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';

/// Repository for persisting and querying [Showup] instances.
///
/// Cascade behaviour: when a [Pact] is deleted, all associated showups
/// (matched by [Showup.pactId]) must be deleted by the caller or by the
/// underlying storage layer. This contract is not enforced here.
abstract class ShowupRepository {
  Future<List<Showup>> getShowupsForDate(DateTime date);
  Future<List<Showup>> getShowupsForDateRange(DateTime start, DateTime end);
  Future<Showup?> getShowupById(String id);
  Future<List<Showup>> getShowupsForPact(String pactId);

  /// Persists a single showup.
  ///
  /// Throws [ArgumentError] if a showup with the same id already exists.
  Future<void> saveShowup(Showup showup);

  /// Persists multiple showups in one operation.
  ///
  /// Showups whose ids already exist are skipped (not saved). Returns a
  /// [SaveShowupsResult] with the count of saved showups and the ids of
  /// any that were skipped.
  ///
  /// **Implementations must treat this as an atomic operation**: either all
  /// new showups are written or none are. Partial writes are not permitted.
  /// Callers (e.g. pact creation) rely on this guarantee to avoid leaving a
  /// pact with an incomplete set of showups.
  Future<SaveShowupsResult> saveShowups(List<Showup> showups);

  /// Updates an existing showup by id.
  ///
  /// Throws [ArgumentError] if no showup with the given id exists.
  Future<void> updateShowup(Showup showup);

  /// Returns the number of showups persisted for the given [pactId].
  ///
  /// Returns 0 if no showups exist for that pact.
  Future<int> countShowupsForPact(String pactId);

  /// Deletes all showups associated with [pactId].
  Future<void> deleteShowupsForPact(String pactId);
}

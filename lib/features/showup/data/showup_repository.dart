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
  Future<void> saveShowup(Showup showup);
  Future<void> saveShowups(List<Showup> showups);
  /// Updates an existing showup by id.
  ///
  /// Throws [ArgumentError] if no showup with the given id exists.
  Future<void> updateShowup(Showup showup);
}

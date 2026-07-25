import 'package:habit_loop/domain/pact/pact_break.dart';

abstract class PactBreakRepository {
  /// All breaks (stopped and unstopped) recorded for a pact, oldest first.
  Future<List<PactBreak>> getBreaksForPact(String pactId);

  /// The break with the given [id], or `null` if none exists.
  Future<PactBreak?> getBreakById(String id);

  /// Persists a new break.
  ///
  /// Throws [ArgumentError] if a break with the same id already exists.
  Future<void> saveBreak(PactBreak pactBreak);

  /// Updates an existing break by id (e.g. to stop it).
  ///
  /// Throws [ArgumentError] if no break with the given id exists.
  Future<void> updateBreak(PactBreak pactBreak);
}

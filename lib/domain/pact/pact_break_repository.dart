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

  /// Deletes all breaks recorded for [pactId]. Callers that delete a pact
  /// directly (bypassing `PactTransactionService`) must call this first —
  /// `pact_breaks.pact_id` has a foreign key to `pacts.id`.
  Future<void> deleteBreaksForPact(String pactId);
}

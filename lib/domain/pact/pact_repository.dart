import 'package:habit_loop/domain/pact/pact.dart';

abstract class PactRepository {
  Future<List<Pact>> getActivePacts();
  Future<List<Pact>> getAllPacts();
  Future<Pact?> getPactById(String id);

  /// Returns the pact whose `predecessorPactId` equals [pactId], if any.
  ///
  /// A pact has at most one successor (HAB-202) — enforced by [savePact].
  Future<Pact?> getSuccessor(String pactId);

  /// Persists a new pact.
  ///
  /// Throws [ArgumentError] if a pact with the same id already exists, or if
  /// [pact] has a non-null `predecessorPactId` that already has a successor
  /// (each pact may have at most one successor — HAB-202).
  Future<void> savePact(Pact pact);

  /// Updates an existing pact by id.
  ///
  /// Throws [ArgumentError] if no pact with the given id exists.
  Future<void> updatePact(Pact pact);

  /// Deletes a pact by id.
  ///
  /// Used for rollback when a dependent write (e.g. saving showups) fails
  /// after the pact was already persisted. No-op if the id does not exist.
  Future<void> deletePact(String id);

  /// Sets the archived flag on a pact and marks it dirty for sync.
  Future<void> archivePact(String id, bool archived);
}

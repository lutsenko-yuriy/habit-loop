import 'package:habit_loop/features/pact/domain/pact.dart';

abstract class PactRepository {
  Future<List<Pact>> getActivePacts();
  Future<List<Pact>> getAllPacts();
  Future<Pact?> getPactById(String id);
  /// Persists a new pact.
  ///
  /// Throws [ArgumentError] if a pact with the same id already exists.
  Future<void> savePact(Pact pact);
  /// Updates an existing pact by id.
  ///
  /// Throws [ArgumentError] if no pact with the given id exists.
  Future<void> updatePact(Pact pact);
}

import 'package:habit_loop/features/pact/domain/pact.dart';

abstract class PactRepository {
  Future<List<Pact>> getActivePacts();
  Future<List<Pact>> getAllPacts();
  Future<Pact?> getPactById(String id);
  Future<void> savePact(Pact pact);
  Future<void> updatePact(Pact pact);
}

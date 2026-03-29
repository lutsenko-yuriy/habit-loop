import 'package:habit_loop/features/pact/domain/pact.dart';

abstract class PactRepository {
  Future<List<Pact>> getActivePacts();
  Future<Pact?> getPactById(String id);
}

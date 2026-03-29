import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';

class InMemoryPactRepository implements PactRepository {
  final List<Pact> _pacts;

  InMemoryPactRepository([List<Pact>? pacts]) : _pacts = pacts ?? [];

  @override
  Future<List<Pact>> getActivePacts() async {
    return _pacts.where((p) => p.status == PactStatus.active).toList();
  }

  @override
  Future<Pact?> getPactById(String id) async {
    try {
      return _pacts.firstWhere((p) => p.id == id);
    } on StateError {
      return null;
    }
  }
}

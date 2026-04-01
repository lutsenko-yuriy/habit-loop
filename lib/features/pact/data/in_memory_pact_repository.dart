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

  @override
  Future<void> savePact(Pact pact) async {
    _pacts.add(pact);
  }

  @override
  Future<List<Pact>> getAllPacts() async {
    return List.of(_pacts);
  }

  @override
  Future<void> updatePact(Pact pact) async {
    final index = _pacts.indexWhere((p) => p.id == pact.id);
    if (index == -1) {
      throw ArgumentError('Pact with id "${pact.id}" not found.');
    }
    _pacts[index] = pact;
  }
}

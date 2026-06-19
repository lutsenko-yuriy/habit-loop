import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';

// Fast in-memory fake used by unit tests that don't need SQLite fidelity.
// Migration to sqflite_common_ffi is tracked in HAB-99.
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
    if (_pacts.any((p) => p.id == pact.id)) {
      throw ArgumentError('Pact with id "${pact.id}" already exists.');
    }
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

  @override
  Future<void> deletePact(String id) async {
    _pacts.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> archivePact(String id, bool archived) async {
    final index = _pacts.indexWhere((p) => p.id == id);
    if (index == -1) throw ArgumentError('Pact with id "$id" not found.');
    _pacts[index] = _pacts[index].copyWith(archived: archived);
  }
}

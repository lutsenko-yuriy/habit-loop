import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_break_repository.dart';

// Fast in-memory fake used by unit tests that don't need SQLite fidelity.
class InMemoryPactBreakRepository implements PactBreakRepository {
  final List<PactBreak> _pactBreaks;

  InMemoryPactBreakRepository([List<PactBreak>? pactBreaks])
      : _pactBreaks = pactBreaks != null ? List.of(pactBreaks) : [];

  @override
  Future<List<PactBreak>> getBreaksForPact(String pactId) async {
    final breaks = _pactBreaks.where((b) => b.pactId == pactId).toList();
    breaks.sort((a, b) => a.startDate.compareTo(b.startDate));
    return breaks;
  }

  @override
  Future<void> saveBreak(PactBreak pactBreak) async {
    if (_pactBreaks.any((b) => b.id == pactBreak.id)) {
      throw ArgumentError('PactBreak with id "${pactBreak.id}" already exists.');
    }
    _pactBreaks.add(pactBreak);
  }

  @override
  Future<void> updateBreak(PactBreak pactBreak) async {
    final index = _pactBreaks.indexWhere((b) => b.id == pactBreak.id);
    if (index == -1) {
      throw ArgumentError('PactBreak with id "${pactBreak.id}" not found.');
    }
    _pactBreaks[index] = pactBreak;
  }
}

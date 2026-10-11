import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link_repository.dart';

// Fast in-memory fake used by unit tests that don't need SQLite fidelity.
class InMemoryPactChecklistLinkRepository implements PactChecklistLinkRepository {
  final Map<String, PactChecklistLink> _links;

  InMemoryPactChecklistLinkRepository([Iterable<PactChecklistLink>? links])
      : _links = {for (final l in links ?? const <PactChecklistLink>[]) l.pactId: l};

  @override
  Future<PactChecklistLink?> getForPact(String pactId) async => _links[pactId];

  @override
  Future<Map<String, PactChecklistLink>> getForPacts(Iterable<String> pactIds) async => {
        for (final id in pactIds.toSet())
          if (_links[id] != null) id: _links[id]!,
      };

  @override
  Future<void> upsert(PactChecklistLink link) async => _links[link.pactId] = link;

  @override
  Future<void> delete(String pactId) async => _links.remove(pactId);
}

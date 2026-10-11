import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';

abstract class PactChecklistLinkRepository {
  /// The link for [pactId], or `null` if none.
  Future<PactChecklistLink?> getForPact(String pactId);

  /// Links for the given pacts, keyed by pact id (pacts without a link are absent).
  Future<Map<String, PactChecklistLink>> getForPacts(Iterable<String> pactIds);

  /// Inserts or replaces the link for `link.pactId`. An unknown pact id is accepted
  /// (no FK); the SQLite implementation removes the row when that pact is deleted.
  Future<void> upsert(PactChecklistLink link);

  /// Removes the link for [pactId]; no-op if none.
  Future<void> delete(String pactId);
}

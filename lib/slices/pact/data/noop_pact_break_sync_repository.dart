import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_break_sync_repository.dart';

/// No-op [PactBreakSyncRepository] used as the default provider value.
///
/// Returns an empty dirty list and silently ignores markPactBreakSynced calls.
/// Replaced in production by [SqlitePactBreakRepository] via [AppContainer.overrides].
class NoopPactBreakSyncRepository implements PactBreakSyncRepository {
  const NoopPactBreakSyncRepository();

  @override
  Future<List<PactBreak>> getDirtyPactBreaks() async => [];

  @override
  Future<void> markPactBreakSynced(String pactBreakId, DateTime syncedAt) async {}

  @override
  Future<DateTime?> getPactBreakSyncedAt(String pactBreakId) async => null;

  @override
  Future<void> markAllPactBreaksDirty() async {}
}

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';

/// No-op [PactSyncRepository] used as the default provider value.
///
/// Returns an empty dirty list and silently ignores markPactSynced calls.
/// Replaced in production by [SqlitePactRepository] via [AppContainer.overrides].
class NoopPactSyncRepository implements PactSyncRepository {
  const NoopPactSyncRepository();

  @override
  Future<List<Pact>> getDirtyPacts() async => [];

  @override
  Future<void> markPactSynced(String pactId, DateTime syncedAt) async {}

  @override
  Future<DateTime?> getPactSyncedAt(String pactId) async => null;

  @override
  Future<void> markAllPactsDirty() async {}
}

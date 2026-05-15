import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';

/// No-op [ShowupSyncRepository] used as the default provider value.
///
/// Returns an empty dirty list and silently ignores markShowupSynced calls.
/// Replaced in production by [SqliteShowupRepository] via [AppContainer.overrides].
class NoopShowupSyncRepository implements ShowupSyncRepository {
  const NoopShowupSyncRepository();

  @override
  Future<List<Showup>> getDirtyShowups() async => [];

  @override
  Future<void> markShowupSynced(String showupId, DateTime syncedAt) async {}

  @override
  Future<DateTime?> getShowupSyncedAt(String showupId) async => null;

  @override
  Future<void> markAllShowupsDirty() async {}
}

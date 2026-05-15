import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';

/// Silent no-op implementation of [SyncService].
///
/// Used as the default value of [syncServiceProvider] so that tests and
/// offline/development environments never touch Firestore.
class NoopSyncService implements SyncService {
  const NoopSyncService();

  @override
  Future<void> uploadPact(Pact pact) async {}

  @override
  Future<void> uploadShowup(Showup showup) async {}

  @override
  Future<void> flushDirtyRecords() async {}

  @override
  void triggerManualSync() {}

  @override
  Future<void> forceSyncAll() async {}

  @override
  Future<void> pullRemoteChanges() async {}
}

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/sync/force_sync_result.dart';
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
  Future<void> uploadPactBreak(PactBreak pactBreak) async {}

  @override
  Future<void> uploadUserProfile(UserProfile profile) async {}

  @override
  Future<void> flushDirtyRecords() async {}

  @override
  void triggerManualSync() {}

  @override
  Future<ForceSyncResult> forceSyncAll() async => const ForceSyncResult(attempted: 0, pactsFailed: 0, showupsFailed: 0);

  @override
  Future<void> pullRemoteChanges() async {}

  @override
  Stream<void> get pullCompleted => const Stream.empty();
}

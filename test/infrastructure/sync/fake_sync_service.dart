import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';

/// Test double for [SyncService] that records all calls.
class FakeSyncService implements SyncService {
  final List<String> uploadedPactIds = [];
  final List<String> uploadedShowupIds = [];
  int flushCount = 0;
  int triggerManualSyncCount = 0;
  int forceSyncAllCount = 0;
  int pullRemoteChangesCount = 0;

  @override
  Future<void> uploadPact(Pact pact) async {
    uploadedPactIds.add(pact.id);
  }

  @override
  Future<void> uploadShowup(Showup showup) async {
    uploadedShowupIds.add(showup.id);
  }

  @override
  Future<void> flushDirtyRecords() async {
    flushCount++;
  }

  @override
  void triggerManualSync() {
    triggerManualSyncCount++;
  }

  @override
  Future<void> forceSyncAll() async {
    forceSyncAllCount++;
  }

  @override
  Future<void> pullRemoteChanges() async {
    pullRemoteChangesCount++;
  }
}

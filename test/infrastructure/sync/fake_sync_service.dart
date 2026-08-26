import 'dart:async';

import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/infrastructure/sync/force_sync_result.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';

/// Test double for [SyncService] that records all calls.
class FakeSyncService implements SyncService {
  final _pullCompletedController = StreamController<void>.broadcast();

  final List<String> uploadedPactIds = [];
  final List<String> uploadedShowupIds = [];
  final List<String> uploadedPactBreakIds = [];
  int flushCount = 0;
  int triggerManualSyncCount = 0;
  int forceSyncAllCount = 0;
  int forceSyncAllPactsFailed = 0;
  int forceSyncAllShowupsFailed = 0;
  int forceSyncAllPactBreaksFailed = 0;
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
  Future<void> uploadPactBreak(PactBreak pactBreak) async {
    uploadedPactBreakIds.add(pactBreak.id);
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
  Future<ForceSyncResult> forceSyncAll() async {
    forceSyncAllCount++;
    return ForceSyncResult(
      attempted: forceSyncAllPactsFailed + forceSyncAllShowupsFailed + forceSyncAllPactBreaksFailed,
      pactsFailed: forceSyncAllPactsFailed,
      showupsFailed: forceSyncAllShowupsFailed,
      pactBreaksFailed: forceSyncAllPactBreaksFailed,
    );
  }

  @override
  Future<void> pullRemoteChanges() async {
    pullRemoteChangesCount++;
    emitPullCompleted();
  }

  @override
  Stream<void> get pullCompleted => _pullCompletedController.stream;

  /// Test helper — emits [pullCompleted] directly, without going through
  /// [pullRemoteChanges], so a test can drive the reconciliation trigger in
  /// isolation.
  void emitPullCompleted() => _pullCompletedController.add(null);
}

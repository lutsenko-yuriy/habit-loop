import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';

void main() {
  group('NoopSyncService', () {
    const svc = NoopSyncService();

    final pact = Pact(
      id: 'p1',
      habitName: 'Meditate',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 6, 30),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
    );

    final showup = Showup(
      id: 's1',
      pactId: 'p1',
      scheduledAt: DateTime(2026, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

    test('uploadPact does not throw', () async {
      await expectLater(svc.uploadPact(pact), completes);
    });

    test('uploadShowup does not throw', () async {
      await expectLater(svc.uploadShowup(showup), completes);
    });

    test('flushDirtyRecords does not throw', () async {
      await expectLater(svc.flushDirtyRecords(), completes);
    });

    test('triggerManualSync does not throw', () {
      expect(() => svc.triggerManualSync(), returnsNormally);
    });

    test('pullRemoteChanges does not throw', () async {
      await expectLater(svc.pullRemoteChanges(), completes);
    });
  });
}

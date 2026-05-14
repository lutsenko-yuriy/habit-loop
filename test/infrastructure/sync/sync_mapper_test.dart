import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/sync/sync_mapper.dart';

void main() {
  group('SyncMapper.pactToDocument', () {
    final pact = Pact(
      id: 'p1',
      habitName: 'Meditate',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 6, 30),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
      createdAt: DateTime(2026, 1, 1),
    );

    test('includes all domain fields', () {
      final doc = SyncMapper.pactToDocument(pact);
      expect(doc['id'], 'p1');
      expect(doc['habit_name'], 'Meditate');
      expect(doc['status'], 'active');
      expect(doc['start_date'], pact.startDate.millisecondsSinceEpoch);
      expect(doc['scheduled_end_date'], pact.endDate.millisecondsSinceEpoch);
    });

    test('excludes dirty, synced_at, total_showups', () {
      final doc = SyncMapper.pactToDocument(pact);
      expect(doc.containsKey('dirty'), isFalse);
      expect(doc.containsKey('synced_at'), isFalse);
      expect(doc.containsKey('total_showups'), isFalse);
    });

    test('encodes stopped status correctly', () {
      final stopped = pact.copyWith(status: PactStatus.stopped);
      expect(SyncMapper.pactToDocument(stopped)['status'], 'stopped');
    });

    test('encodes completed status correctly', () {
      final completed = pact.copyWith(status: PactStatus.completed);
      expect(SyncMapper.pactToDocument(completed)['status'], 'completed');
    });
  });

  group('SyncMapper.showupToDocument', () {
    final showup = Showup(
      id: 's1',
      pactId: 'p1',
      scheduledAt: DateTime(2026, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

    test('includes all domain fields', () {
      final doc = SyncMapper.showupToDocument(showup);
      expect(doc['id'], 's1');
      expect(doc['pact_id'], 'p1');
      expect(doc['scheduled_at'], showup.scheduledAt.millisecondsSinceEpoch);
      expect(doc['status'], 'pending');
    });

    test('excludes dirty and synced_at', () {
      final doc = SyncMapper.showupToDocument(showup);
      expect(doc.containsKey('dirty'), isFalse);
      expect(doc.containsKey('synced_at'), isFalse);
    });

    test('encodes done status correctly', () {
      final done = showup.copyWith(status: ShowupStatus.done);
      expect(SyncMapper.showupToDocument(done)['status'], 'done');
    });

    test('encodes failed status correctly', () {
      final failed = showup.copyWith(status: ShowupStatus.failed);
      expect(SyncMapper.showupToDocument(failed)['status'], 'failed');
    });

    test('includes note when present', () {
      final withNote = showup.copyWith(note: 'felt good');
      expect(SyncMapper.showupToDocument(withNote)['note'], 'felt good');
    });
  });
}

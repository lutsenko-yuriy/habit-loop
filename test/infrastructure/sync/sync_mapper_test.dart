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

    test('includes updated_at when provided', () {
      final updatedAt = DateTime(2026, 5, 1);
      final doc = SyncMapper.pactToDocument(pact, updatedAt: updatedAt);
      expect(doc['updated_at'], updatedAt.millisecondsSinceEpoch);
    });

    test('includes updated_at as a non-null timestamp when not provided', () {
      final doc = SyncMapper.pactToDocument(pact);
      expect(doc.containsKey('updated_at'), isTrue);
      expect(doc['updated_at'], isA<int>());
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

    test('includes updated_at when provided', () {
      final updatedAt = DateTime(2026, 5, 1);
      final doc = SyncMapper.showupToDocument(showup, updatedAt: updatedAt);
      expect(doc['updated_at'], updatedAt.millisecondsSinceEpoch);
    });

    test('includes updated_at as a non-null timestamp when not provided', () {
      final doc = SyncMapper.showupToDocument(showup);
      expect(doc.containsKey('updated_at'), isTrue);
      expect(doc['updated_at'], isA<int>());
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

    test('encodes redeemable=true as true', () {
      expect(SyncMapper.showupToDocument(showup)['redeemable'], isTrue);
    });

    test('encodes redeemable=false as false', () {
      final notRedeemable = showup.copyWith(redeemable: false);
      expect(SyncMapper.showupToDocument(notRedeemable)['redeemable'], isFalse);
    });
  });

  group('SyncMapper.pactFromDocument', () {
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

    test('round-trips pact through pactToDocument → pactFromDocument', () {
      final doc = SyncMapper.pactToDocument(pact);
      final decoded = SyncMapper.pactFromDocument(doc);

      expect(decoded.id, pact.id);
      expect(decoded.habitName, pact.habitName);
      expect(decoded.startDate, pact.startDate);
      expect(decoded.endDate, pact.endDate);
      expect(decoded.showupDuration, pact.showupDuration);
      expect(decoded.status, pact.status);
    });

    test('decodes stopped pact status', () {
      final stopped = pact.copyWith(status: PactStatus.stopped);
      final doc = SyncMapper.pactToDocument(stopped);
      expect(SyncMapper.pactFromDocument(doc).status, PactStatus.stopped);
    });

    test('decodes completed pact status', () {
      final completed = pact.copyWith(status: PactStatus.completed);
      final doc = SyncMapper.pactToDocument(completed);
      expect(SyncMapper.pactFromDocument(doc).status, PactStatus.completed);
    });

    test('decodes nullable reminder_offset', () {
      final withReminder = pact.copyWith(reminderOffset: const Duration(minutes: 10));
      final doc = SyncMapper.pactToDocument(withReminder);
      expect(SyncMapper.pactFromDocument(doc).reminderOffset, const Duration(minutes: 10));
    });

    test('decodes null reminder_offset', () {
      final doc = SyncMapper.pactToDocument(pact);
      expect(SyncMapper.pactFromDocument(doc).reminderOffset, isNull);
    });

    test('archived false round-trips through pactToDocument → pactFromDocument', () {
      final doc = SyncMapper.pactToDocument(pact);
      expect(SyncMapper.pactFromDocument(doc).archived, isFalse);
    });

    test('archived true round-trips through pactToDocument → pactFromDocument', () {
      final archived = pact.copyWith(archived: true);
      final doc = SyncMapper.pactToDocument(archived);
      expect(SyncMapper.pactFromDocument(doc).archived, isTrue);
    });

    test('archived absent in document defaults to false (backward compat for old docs)', () {
      final doc = SyncMapper.pactToDocument(pact)..remove('archived');
      expect(SyncMapper.pactFromDocument(doc).archived, isFalse);
    });
  });

  group('SyncMapper.showupFromDocument', () {
    final showup = Showup(
      id: 's1',
      pactId: 'p1',
      scheduledAt: DateTime(2026, 1, 1, 8, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

    test('round-trips showup through showupToDocument → showupFromDocument', () {
      final doc = SyncMapper.showupToDocument(showup);
      final decoded = SyncMapper.showupFromDocument(doc);

      expect(decoded.id, showup.id);
      expect(decoded.pactId, showup.pactId);
      expect(decoded.scheduledAt, showup.scheduledAt);
      expect(decoded.duration, showup.duration);
      expect(decoded.status, showup.status);
    });

    test('decodes done showup status', () {
      final done = showup.copyWith(status: ShowupStatus.done);
      final doc = SyncMapper.showupToDocument(done);
      expect(SyncMapper.showupFromDocument(doc).status, ShowupStatus.done);
    });

    test('decodes note', () {
      final withNote = showup.copyWith(note: 'felt great');
      final doc = SyncMapper.showupToDocument(withNote);
      expect(SyncMapper.showupFromDocument(doc).note, 'felt great');
    });

    test('decodes redeemable=true', () {
      final doc = SyncMapper.showupToDocument(showup);
      expect(SyncMapper.showupFromDocument(doc).redeemable, isTrue);
    });

    test('decodes redeemable=false', () {
      final notRedeemable = showup.copyWith(redeemable: false);
      final doc = SyncMapper.showupToDocument(notRedeemable);
      expect(SyncMapper.showupFromDocument(doc).redeemable, isFalse);
    });

    test('defaults redeemable to true when absent in legacy document', () {
      final doc = SyncMapper.showupToDocument(showup)..remove('redeemable');
      expect(SyncMapper.showupFromDocument(doc).redeemable, isTrue);
    });
  });

  group('SyncMapper.updatedAtFromDocument', () {
    test('extracts updated_at when present', () {
      final t = DateTime(2026, 5, 14);
      final doc = {'updated_at': t.millisecondsSinceEpoch};
      expect(SyncMapper.updatedAtFromDocument(doc), t);
    });

    test('returns null when updated_at is absent', () {
      expect(SyncMapper.updatedAtFromDocument({}), isNull);
    });

    test('returns null when updated_at is null', () {
      expect(SyncMapper.updatedAtFromDocument({'updated_at': null}), isNull);
    });
  });
}

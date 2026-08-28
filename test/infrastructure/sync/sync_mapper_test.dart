import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
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

    test('includes predecessor_pact_id when set', () {
      final chained = Pact(
        id: 'p2',
        habitName: 'Meditate (v2)',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
        status: PactStatus.active,
        predecessorPactId: 'p1',
      );
      expect(SyncMapper.pactToDocument(chained)['predecessor_pact_id'], 'p1');
    });

    test('includes predecessor_pact_id as null when not set', () {
      expect(SyncMapper.pactToDocument(pact)['predecessor_pact_id'], isNull);
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

    test('decodes predecessor_pact_id when present', () {
      final chained = pact.copyWith();
      final doc = SyncMapper.pactToDocument(chained)..['predecessor_pact_id'] = 'p0';
      expect(SyncMapper.pactFromDocument(doc).predecessorPactId, 'p0');
    });

    test('decodes predecessor_pact_id as null when absent (tolerates a dangling/legacy document)', () {
      final doc = SyncMapper.pactToDocument(pact)..remove('predecessor_pact_id');
      expect(SyncMapper.pactFromDocument(doc).predecessorPactId, isNull);
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

  group('SyncMapper.pactBreakToDocument', () {
    final pactBreak = PactBreak(
      id: 'b1',
      pactId: 'p1',
      startDate: DateTime(2026, 3, 1),
      rationale: 'Recovering from a cold',
      plannedEndDate: DateTime(2026, 3, 10),
      createdAt: DateTime(2026, 2, 28),
    );

    test('includes all domain fields', () {
      final doc = SyncMapper.pactBreakToDocument(pactBreak);
      expect(doc['id'], 'b1');
      expect(doc['pact_id'], 'p1');
      expect(doc['start_date'], pactBreak.startDate.millisecondsSinceEpoch);
      expect(doc['rationale'], 'Recovering from a cold');
      expect(doc['planned_end_date'], pactBreak.plannedEndDate!.millisecondsSinceEpoch);
      expect(doc['created_at'], pactBreak.createdAt!.millisecondsSinceEpoch);
    });

    test('excludes dirty and synced_at', () {
      final doc = SyncMapper.pactBreakToDocument(pactBreak);
      expect(doc.containsKey('dirty'), isFalse);
      expect(doc.containsKey('synced_at'), isFalse);
    });

    test('includes updated_at when provided', () {
      final updatedAt = DateTime(2026, 5, 1);
      final doc = SyncMapper.pactBreakToDocument(pactBreak, updatedAt: updatedAt);
      expect(doc['updated_at'], updatedAt.millisecondsSinceEpoch);
    });

    test('includes updated_at as a non-null timestamp when not provided', () {
      final doc = SyncMapper.pactBreakToDocument(pactBreak);
      expect(doc.containsKey('updated_at'), isTrue);
      expect(doc['updated_at'], isA<int>());
    });

    test('encodes null plannedEndDate as null (open-ended break)', () {
      final open = pactBreak.copyWith(clearPlannedEndDate: true);
      expect(SyncMapper.pactBreakToDocument(open)['planned_end_date'], isNull);
    });

    test('encodes stoppedAt when present', () {
      final stopped = pactBreak.copyWith(stoppedAt: DateTime(2026, 3, 5));
      expect(SyncMapper.pactBreakToDocument(stopped)['stopped_at'], DateTime(2026, 3, 5).millisecondsSinceEpoch);
    });

    test('encodes null stoppedAt as null', () {
      expect(SyncMapper.pactBreakToDocument(pactBreak)['stopped_at'], isNull);
    });
  });

  group('SyncMapper.pactBreakFromDocument', () {
    final pactBreak = PactBreak(
      id: 'b1',
      pactId: 'p1',
      startDate: DateTime(2026, 3, 1),
      rationale: 'Recovering from a cold',
      plannedEndDate: DateTime(2026, 3, 10),
      createdAt: DateTime(2026, 2, 28),
    );

    test('round-trips a pact break through pactBreakToDocument → pactBreakFromDocument', () {
      final doc = SyncMapper.pactBreakToDocument(pactBreak);
      final decoded = SyncMapper.pactBreakFromDocument(doc);

      expect(decoded.id, pactBreak.id);
      expect(decoded.pactId, pactBreak.pactId);
      expect(decoded.startDate, pactBreak.startDate);
      expect(decoded.rationale, pactBreak.rationale);
      expect(decoded.plannedEndDate, pactBreak.plannedEndDate);
      expect(decoded.createdAt, pactBreak.createdAt);
    });

    test('decodes null plannedEndDate (open-ended break)', () {
      final open = pactBreak.copyWith(clearPlannedEndDate: true);
      final doc = SyncMapper.pactBreakToDocument(open);
      expect(SyncMapper.pactBreakFromDocument(doc).plannedEndDate, isNull);
    });

    test('decodes stoppedAt when present', () {
      final stopped = pactBreak.copyWith(stoppedAt: DateTime(2026, 3, 5));
      final doc = SyncMapper.pactBreakToDocument(stopped);
      expect(SyncMapper.pactBreakFromDocument(doc).stoppedAt, DateTime(2026, 3, 5));
    });

    test('decodes null stoppedAt as null', () {
      final doc = SyncMapper.pactBreakToDocument(pactBreak);
      expect(SyncMapper.pactBreakFromDocument(doc).stoppedAt, isNull);
    });
  });

  group('SyncMapper.userProfileToDocument', () {
    test('includes display_name and the given updated_at', () {
      final profile = UserProfile(displayName: 'Jamie', updatedAt: DateTime(2026, 5, 1));
      final doc = SyncMapper.userProfileToDocument(profile, updatedAt: DateTime(2026, 5, 2));
      expect(doc['display_name'], 'Jamie');
      expect(doc['updated_at'], DateTime(2026, 5, 2).millisecondsSinceEpoch);
    });

    test('encodes null displayName as null', () {
      final profile = UserProfile(updatedAt: DateTime(2026, 5, 1));
      expect(SyncMapper.userProfileToDocument(profile)['display_name'], isNull);
    });

    // Upload time, not profile.updatedAt (edit time) — see the doc comment:
    // mixing the two would let a stale flush overwrite a newer remote edit.
    test('defaults updated_at to DateTime.now(), not profile.updatedAt', () {
      final editTime = DateTime(2020, 1, 1);
      final profile = UserProfile(displayName: 'Jamie', updatedAt: editTime);
      final doc = SyncMapper.userProfileToDocument(profile);
      expect(doc['updated_at'], isNot(editTime.millisecondsSinceEpoch));
      expect(doc['updated_at'], isA<int>());
    });
  });

  group('SyncMapper.userProfileFromDocument', () {
    test('round-trips a profile through userProfileToDocument → userProfileFromDocument', () {
      final profile = UserProfile(displayName: 'Jamie', updatedAt: DateTime(2026, 5, 1));
      final doc = SyncMapper.userProfileToDocument(profile, updatedAt: DateTime(2026, 5, 1));
      final decoded = SyncMapper.userProfileFromDocument(doc);

      expect(decoded.displayName, profile.displayName);
      expect(decoded.updatedAt, DateTime(2026, 5, 1));
    });

    test('decodes null displayName', () {
      final profile = UserProfile(updatedAt: DateTime(2026, 5, 1));
      final doc = SyncMapper.userProfileToDocument(profile, updatedAt: DateTime(2026, 5, 1));
      expect(SyncMapper.userProfileFromDocument(doc).displayName, isNull);
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

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/persistence/pact_mapper.dart';

void main() {
  // Use local-time DateTime to match PactBuilder output. The mapper stores epoch
  // milliseconds and must reconstruct local-time values on read, so test fixtures
  // must also use local time to produce correct round-trip assertions.
  final startDate = DateTime(2026, 1, 1);
  final endDate = DateTime(2026, 7, 1);
  final createdAt = DateTime(2026, 1, 1, 10, 0, 0);
  const schedule = DailySchedule(timeOfDay: Duration(hours: 8));
  const showupDuration = Duration(minutes: 30);
  const reminderOffset = Duration(minutes: 15);

  Pact basePact({
    PactStatus status = PactStatus.active,
    Duration? pactReminderOffset,
    String? stopReason,
    DateTime? pactCreatedAt,
    PactStats? stats,
  }) =>
      Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: startDate,
        endDate: endDate,
        showupDuration: showupDuration,
        schedule: schedule,
        status: status,
        reminderOffset: pactReminderOffset,
        stopReason: stopReason,
        createdAt: pactCreatedAt,
        stats: stats,
      );

  group('PactMapper', () {
    group('toRow', () {
      test('maps required fields correctly', () {
        final pact = basePact();
        final row = PactMapper.toRow(pact);

        expect(row['id'], equals('pact-1'));
        expect(row['habit_name'], equals('Meditate'));
        expect(row['start_date'], equals(startDate.millisecondsSinceEpoch));
        expect(row['scheduled_end_date'], equals(endDate.millisecondsSinceEpoch));
        expect(row['actual_end_date'], equals(endDate.millisecondsSinceEpoch));
        expect(row['showup_duration'], equals(showupDuration.inMicroseconds));
        expect(row['status'], equals('active'));
        expect(row['schedule'], isA<String>());
      });

      test('maps reminder_offset when set', () {
        final pact = basePact(pactReminderOffset: reminderOffset);
        final row = PactMapper.toRow(pact);
        expect(row['reminder_offset'], equals(reminderOffset.inMicroseconds));
      });

      test('maps reminder_offset as null when not set', () {
        final pact = basePact();
        final row = PactMapper.toRow(pact);
        expect(row['reminder_offset'], isNull);
      });

      test('maps stop_reason when set', () {
        final pact = basePact(status: PactStatus.stopped, stopReason: 'Lost interest');
        final row = PactMapper.toRow(pact);
        expect(row['stop_reason'], equals('Lost interest'));
      });

      test('maps stop_reason as null when not set', () {
        final pact = basePact();
        final row = PactMapper.toRow(pact);
        expect(row['stop_reason'], isNull);
      });

      test('maps created_at when set', () {
        final pact = basePact(pactCreatedAt: createdAt);
        final row = PactMapper.toRow(pact);
        expect(row['created_at'], equals(createdAt.millisecondsSinceEpoch));
      });

      test('maps created_at as null when not set', () {
        final pact = basePact();
        final row = PactMapper.toRow(pact);
        expect(row['created_at'], isNull);
      });

      test('maps total_showups as null (written by savePactWithShowups, not by mapper)', () {
        final pact = basePact();
        final row = PactMapper.toRow(pact);
        expect(row['total_showups'], isNull);
      });

      test('does not persist stats — stats field is absent from row', () {
        final stats = PactStats(
          showupsDone: 5,
          showupsFailed: 2,
          showupsRemaining: 10,
          currentStreak: 3,
          startDate: startDate,
          endDate: endDate,
          totalShowups: 17,
        );
        final pact = basePact(stats: stats);
        final row = PactMapper.toRow(pact);
        // stats columns are not written — the old stats_* columns no longer exist
        expect(row.containsKey('stats_done'), isFalse);
        expect(row.containsKey('stats_failed'), isFalse);
        expect(row.containsKey('stats_remaining'), isFalse);
        expect(row.containsKey('stats_streak'), isFalse);
      });

      test('maps PactStatus.stopped correctly', () {
        final pact = basePact(status: PactStatus.stopped);
        expect(PactMapper.toRow(pact)['status'], equals('stopped'));
      });

      test('maps PactStatus.completed correctly', () {
        final pact = basePact(status: PactStatus.completed);
        expect(PactMapper.toRow(pact)['status'], equals('completed'));
      });
    });

    group('fromRow', () {
      Map<String, dynamic> baseRow() => {
            'id': 'pact-1',
            'habit_name': 'Meditate',
            'start_date': startDate.millisecondsSinceEpoch,
            'scheduled_end_date': endDate.millisecondsSinceEpoch,
            'actual_end_date': endDate.millisecondsSinceEpoch,
            'showup_duration': showupDuration.inMicroseconds,
            'schedule': '{"type":"daily","timeOfDay":${const Duration(hours: 8).inMicroseconds}}',
            'status': 'active',
            'reminder_offset': null,
            'stop_reason': null,
            'created_at': null,
            'total_showups': null,
          };

      test('reconstructs required fields correctly', () {
        final pact = PactMapper.fromRow(baseRow());

        expect(pact.id, equals('pact-1'));
        expect(pact.habitName, equals('Meditate'));
        expect(pact.startDate, equals(startDate));
        expect(pact.endDate, equals(endDate));
        expect(pact.showupDuration, equals(showupDuration));
        expect(pact.status, equals(PactStatus.active));
        expect(pact.schedule, equals(schedule));
      });

      test('reconstructs reminderOffset when present', () {
        final row = baseRow()..['reminder_offset'] = reminderOffset.inMicroseconds;
        final pact = PactMapper.fromRow(row);
        expect(pact.reminderOffset, equals(reminderOffset));
      });

      test('reconstructs reminderOffset as null when absent', () {
        final pact = PactMapper.fromRow(baseRow());
        expect(pact.reminderOffset, isNull);
      });

      test('reconstructs stopReason when present', () {
        final row = baseRow()
          ..['status'] = 'stopped'
          ..['stop_reason'] = 'Lost interest';
        final pact = PactMapper.fromRow(row);
        expect(pact.stopReason, equals('Lost interest'));
      });

      test('reconstructs stopReason as null when absent', () {
        final pact = PactMapper.fromRow(baseRow());
        expect(pact.stopReason, isNull);
      });

      test('reconstructs createdAt when present', () {
        final row = baseRow()..['created_at'] = createdAt.millisecondsSinceEpoch;
        final pact = PactMapper.fromRow(row);
        expect(pact.createdAt, equals(createdAt));
      });

      test('reconstructs createdAt as null for legacy rows', () {
        final pact = PactMapper.fromRow(baseRow());
        expect(pact.createdAt, isNull);
      });

      test('stats is always null after fromRow (computed at read time)', () {
        final pact = PactMapper.fromRow(baseRow());
        expect(pact.stats, isNull);
      });

      test('total_showups NULL in row does not cause error', () {
        final row = baseRow()..['total_showups'] = null;
        expect(() => PactMapper.fromRow(row), returnsNormally);
      });

      test('total_showups integer in row does not cause error', () {
        final row = baseRow()..['total_showups'] = 182;
        expect(() => PactMapper.fromRow(row), returnsNormally);
      });

      test('reconstructs PactStatus.stopped', () {
        final row = baseRow()..['status'] = 'stopped';
        expect(PactMapper.fromRow(row).status, equals(PactStatus.stopped));
      });

      test('reconstructs PactStatus.completed', () {
        final row = baseRow()..['status'] = 'completed';
        expect(PactMapper.fromRow(row).status, equals(PactStatus.completed));
      });

      test('throws ArgumentError for unknown status', () {
        final row = baseRow()..['status'] = 'unknown';
        expect(() => PactMapper.fromRow(row), throwsArgumentError);
      });

      test('reconstructs startDate as local-time DateTime (not UTC)', () {
        // Regression: fromRow must not use isUtc: true; a UTC+N user would get
        // midnight UTC instead of midnight local, causing date boundary errors
        // in ShowupGenerator's date iteration.
        final localStart = DateTime(2026, 3, 1); // local midnight
        final row = baseRow()..['start_date'] = localStart.millisecondsSinceEpoch;
        final pact = PactMapper.fromRow(row);
        expect(pact.startDate.isUtc, isFalse);
        expect(pact.startDate.hour, equals(localStart.hour));
      });
    });

    group('round-trip', () {
      test('local-time dates preserve hour after round-trip', () {
        // Regression: all DateTime fields in fromRow must use local time.
        // PactBuilder normalises startDate to local midnight; after a round-trip
        // the value must still be local midnight, not UTC midnight.
        final localStart = DateTime(2026, 6, 1); // local midnight
        final localEnd = DateTime(2026, 12, 1); // local midnight
        final localCreatedAt = DateTime(2026, 6, 1, 9, 30); // local 9:30 AM
        final pact = Pact(
          id: 'pact-local-rt',
          habitName: 'Jog',
          startDate: localStart,
          endDate: localEnd,
          showupDuration: const Duration(minutes: 30),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
          createdAt: localCreatedAt,
        );
        final restored = PactMapper.fromRow(PactMapper.toRow(pact));
        expect(restored.startDate.isUtc, isFalse);
        expect(restored.startDate.hour, equals(localStart.hour));
        expect(restored.endDate.isUtc, isFalse);
        expect(restored.endDate.hour, equals(localEnd.hour));
        expect(restored.createdAt!.isUtc, isFalse);
        expect(restored.createdAt!.hour, equals(localCreatedAt.hour));
      });

      test('full pact round-trips correctly (ignoring stats)', () {
        final original = Pact(
          id: 'pact-rt',
          habitName: 'Jog',
          startDate: startDate,
          endDate: endDate,
          showupDuration: const Duration(minutes: 45),
          schedule: const WeekdaySchedule(
            entries: [
              WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 6, minutes: 30)),
              WeekdayEntry(weekday: DateTime.thursday, timeOfDay: Duration(hours: 6, minutes: 30)),
            ],
          ),
          status: PactStatus.active,
          reminderOffset: const Duration(minutes: 10),
          stopReason: null,
          createdAt: createdAt,
        );

        final row = PactMapper.toRow(original);
        final restored = PactMapper.fromRow(row);

        expect(restored.id, equals(original.id));
        expect(restored.habitName, equals(original.habitName));
        expect(restored.startDate, equals(original.startDate));
        expect(restored.endDate, equals(original.endDate));
        expect(restored.showupDuration, equals(original.showupDuration));
        expect(restored.schedule, equals(original.schedule));
        expect(restored.status, equals(original.status));
        expect(restored.reminderOffset, equals(original.reminderOffset));
        expect(restored.stopReason, equals(original.stopReason));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.stats, isNull);
      });
    });
  });
}

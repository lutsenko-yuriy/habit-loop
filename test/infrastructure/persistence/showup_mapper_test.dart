import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/persistence/showup_mapper.dart';

void main() {
  // Use local-time DateTime to match ShowupGenerator output. The mapper stores
  // epoch milliseconds and must reconstruct local-time values on read, so test
  // fixtures must also use local time to produce correct round-trip assertions.
  final scheduledAt = DateTime(2026, 3, 15, 8, 0, 0);
  const duration = Duration(minutes: 30);

  Showup baseShowup({ShowupStatus status = ShowupStatus.pending, String? note}) => Showup(
        id: 'showup-1',
        pactId: 'pact-1',
        scheduledAt: scheduledAt,
        duration: duration,
        status: status,
        note: note,
      );

  group('ShowupMapper', () {
    group('toRow', () {
      test('maps required fields correctly', () {
        final showup = baseShowup();
        final row = ShowupMapper.toRow(showup);

        expect(row['id'], equals('showup-1'));
        expect(row['pact_id'], equals('pact-1'));
        expect(row['scheduled_at'], equals(scheduledAt.millisecondsSinceEpoch));
        expect(row['duration'], equals(duration.inMicroseconds));
        expect(row['status'], equals('pending'));
        expect(row['note'], isNull);
      });

      test('maps note when set', () {
        final showup = baseShowup(note: 'Felt great today');
        final row = ShowupMapper.toRow(showup);
        expect(row['note'], equals('Felt great today'));
      });

      test('maps note as null when not set', () {
        final showup = baseShowup();
        final row = ShowupMapper.toRow(showup);
        expect(row['note'], isNull);
      });

      test('maps ShowupStatus.done correctly', () {
        final showup = baseShowup(status: ShowupStatus.done);
        expect(ShowupMapper.toRow(showup)['status'], equals('done'));
      });

      test('maps ShowupStatus.failed correctly', () {
        final showup = baseShowup(status: ShowupStatus.failed);
        expect(ShowupMapper.toRow(showup)['status'], equals('failed'));
      });

      test('maps dirty as 1 when true (default)', () {
        final showup = baseShowup();
        expect(ShowupMapper.toRow(showup)['dirty'], equals(1));
      });

      test('maps dirty as 0 when false', () {
        final showup = Showup(
          id: 'showup-1',
          pactId: 'pact-1',
          scheduledAt: scheduledAt,
          duration: duration,
          status: ShowupStatus.pending,
          dirty: false,
        );
        expect(ShowupMapper.toRow(showup)['dirty'], equals(0));
      });

      test('maps synced_at as null when not set', () {
        expect(ShowupMapper.toRow(baseShowup())['synced_at'], isNull);
      });

      test('maps synced_at as epoch millis when set', () {
        final syncedAt = DateTime(2026, 4, 1, 12, 0);
        final showup = Showup(
          id: 'showup-1',
          pactId: 'pact-1',
          scheduledAt: scheduledAt,
          duration: duration,
          status: ShowupStatus.pending,
          dirty: false,
          syncedAt: syncedAt,
        );
        expect(ShowupMapper.toRow(showup)['synced_at'], equals(syncedAt.millisecondsSinceEpoch));
      });

      test('maps duration as microseconds', () {
        const dur = Duration(hours: 1, minutes: 30);
        final showup = Showup(
          id: 's',
          pactId: 'p',
          scheduledAt: scheduledAt,
          duration: dur,
          status: ShowupStatus.pending,
        );
        expect(ShowupMapper.toRow(showup)['duration'], equals(dur.inMicroseconds));
      });
    });

    group('fromRow', () {
      Map<String, dynamic> baseRow() => {
            'id': 'showup-1',
            'pact_id': 'pact-1',
            'scheduled_at': scheduledAt.millisecondsSinceEpoch,
            'duration': duration.inMicroseconds,
            'status': 'pending',
            'note': null,
            'dirty': 1,
            'synced_at': null,
          };

      test('reconstructs required fields correctly', () {
        final showup = ShowupMapper.fromRow(baseRow());

        expect(showup.id, equals('showup-1'));
        expect(showup.pactId, equals('pact-1'));
        expect(showup.scheduledAt, equals(scheduledAt));
        expect(showup.duration, equals(duration));
        expect(showup.status, equals(ShowupStatus.pending));
        expect(showup.note, isNull);
      });

      test('reconstructs note when present', () {
        final row = baseRow()..['note'] = 'Felt great today';
        expect(ShowupMapper.fromRow(row).note, equals('Felt great today'));
      });

      test('reconstructs note as null when absent', () {
        expect(ShowupMapper.fromRow(baseRow()).note, isNull);
      });

      test('reconstructs ShowupStatus.done', () {
        final row = baseRow()..['status'] = 'done';
        expect(ShowupMapper.fromRow(row).status, equals(ShowupStatus.done));
      });

      test('reconstructs ShowupStatus.failed', () {
        final row = baseRow()..['status'] = 'failed';
        expect(ShowupMapper.fromRow(row).status, equals(ShowupStatus.failed));
      });

      test('throws ArgumentError for unknown status', () {
        final row = baseRow()..['status'] = 'unknown';
        expect(() => ShowupMapper.fromRow(row), throwsArgumentError);
      });

      test('reconstructs dirty as true when column is 1', () {
        final row = baseRow()..['dirty'] = 1;
        expect(ShowupMapper.fromRow(row).dirty, isTrue);
      });

      test('reconstructs dirty as false when column is 0', () {
        final row = baseRow()..['dirty'] = 0;
        expect(ShowupMapper.fromRow(row).dirty, isFalse);
      });

      test('reconstructs syncedAt as null when column is null', () {
        expect(ShowupMapper.fromRow(baseRow()).syncedAt, isNull);
      });

      test('reconstructs syncedAt from epoch millis when column is set', () {
        final syncedAt = DateTime(2026, 4, 1, 12, 0);
        final row = baseRow()..['synced_at'] = syncedAt.millisecondsSinceEpoch;
        expect(ShowupMapper.fromRow(row).syncedAt, equals(syncedAt));
      });

      test('reconstructs scheduledAt as local-time DateTime (not UTC)', () {
        final showup = ShowupMapper.fromRow(baseRow());
        expect(showup.scheduledAt.isUtc, isFalse);
      });

      test('reconstructs duration from microseconds correctly', () {
        const original = Duration(hours: 1, minutes: 15, seconds: 30);
        final row = baseRow()..['duration'] = original.inMicroseconds;
        expect(ShowupMapper.fromRow(row).duration, equals(original));
      });
    });

    group('round-trip', () {
      test('local-time scheduledAt preserves hour after round-trip', () {
        // Regression: fromRow must not use isUtc: true; a UTC+N user would see
        // the wrong hour if the reconstructed DateTime were UTC instead of local.
        final localScheduledAt = DateTime(2026, 6, 15, 8, 0); // local time, 8:00 AM
        final showup = Showup(
          id: 'showup-local',
          pactId: 'pact-local',
          scheduledAt: localScheduledAt,
          duration: const Duration(minutes: 30),
          status: ShowupStatus.pending,
        );
        final restored = ShowupMapper.fromRow(ShowupMapper.toRow(showup));
        expect(restored.scheduledAt.hour, equals(localScheduledAt.hour));
        expect(restored.scheduledAt.isUtc, isFalse);
      });

      test('pending showup without note round-trips correctly', () {
        final original = baseShowup();
        final restored = ShowupMapper.fromRow(ShowupMapper.toRow(original));
        expect(restored, equals(original));
      });

      test('done showup with note round-trips correctly', () {
        final original = baseShowup(status: ShowupStatus.done, note: 'Best session ever');
        final restored = ShowupMapper.fromRow(ShowupMapper.toRow(original));
        expect(restored, equals(original));
      });

      test('failed showup without note round-trips correctly', () {
        final original = baseShowup(status: ShowupStatus.failed);
        final restored = ShowupMapper.fromRow(ShowupMapper.toRow(original));
        expect(restored, equals(original));
      });

      test('showup with dirty=false and syncedAt set round-trips correctly', () {
        final syncedAt = DateTime(2026, 5, 1, 9, 0);
        final original = Showup(
          id: 'showup-1',
          pactId: 'pact-1',
          scheduledAt: scheduledAt,
          duration: duration,
          status: ShowupStatus.done,
          dirty: false,
          syncedAt: syncedAt,
        );
        final restored = ShowupMapper.fromRow(ShowupMapper.toRow(original));
        expect(restored.dirty, isFalse);
        expect(restored.syncedAt, equals(syncedAt));
        expect(restored, equals(original));
      });
    });
  });
}

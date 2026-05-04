import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/persistence/showup_mapper.dart';

void main() {
  final scheduledAt = DateTime.utc(2026, 3, 15, 8, 0, 0);
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

      test('reconstructs scheduledAt as UTC DateTime', () {
        final showup = ShowupMapper.fromRow(baseRow());
        expect(showup.scheduledAt.isUtc, isTrue);
      });

      test('reconstructs duration from microseconds correctly', () {
        const original = Duration(hours: 1, minutes: 15, seconds: 30);
        final row = baseRow()..['duration'] = original.inMicroseconds;
        expect(ShowupMapper.fromRow(row).duration, equals(original));
      });
    });

    group('round-trip', () {
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
    });
  });
}

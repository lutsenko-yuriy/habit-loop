import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/infrastructure/persistence/pact_break_mapper.dart';

void main() {
  final startDate = DateTime(2026, 3, 1);
  final plannedEndDate = DateTime(2026, 3, 10);
  final createdAt = DateTime(2026, 3, 1, 9, 0);
  final stoppedAt = DateTime(2026, 3, 5);

  PactBreak baseBreak({
    DateTime? plannedEndDate,
    DateTime? createdAt,
    DateTime? stoppedAt,
  }) =>
      PactBreak(
        id: 'break-1',
        pactId: 'pact-1',
        startDate: startDate,
        rationale: 'Recovering from a cold',
        plannedEndDate: plannedEndDate,
        createdAt: createdAt,
        stoppedAt: stoppedAt,
      );

  group('PactBreakMapper', () {
    group('toRow', () {
      test('maps required fields correctly', () {
        final row = PactBreakMapper.toRow(baseBreak());

        expect(row['id'], equals('break-1'));
        expect(row['pact_id'], equals('pact-1'));
        expect(row['start_date'], equals(startDate.millisecondsSinceEpoch));
        expect(row['rationale'], equals('Recovering from a cold'));
      });

      test('maps plannedEndDate as null when open-ended', () {
        expect(PactBreakMapper.toRow(baseBreak())['planned_end_date'], isNull);
      });

      test('maps plannedEndDate when set', () {
        final row = PactBreakMapper.toRow(baseBreak(plannedEndDate: plannedEndDate));
        expect(row['planned_end_date'], equals(plannedEndDate.millisecondsSinceEpoch));
      });

      test('maps createdAt as null when unset', () {
        expect(PactBreakMapper.toRow(baseBreak())['created_at'], isNull);
      });

      test('maps createdAt when set', () {
        final row = PactBreakMapper.toRow(baseBreak(createdAt: createdAt));
        expect(row['created_at'], equals(createdAt.millisecondsSinceEpoch));
      });

      test('maps stoppedAt as null when not stopped', () {
        expect(PactBreakMapper.toRow(baseBreak())['stopped_at'], isNull);
      });

      test('maps stoppedAt when set', () {
        final row = PactBreakMapper.toRow(baseBreak(stoppedAt: stoppedAt));
        expect(row['stopped_at'], equals(stoppedAt.millisecondsSinceEpoch));
      });

      test('always writes dirty=1 — every insert/update is queued for sync', () {
        expect(PactBreakMapper.toRow(baseBreak())['dirty'], equals(1));
      });

      test('always writes synced_at=null — managed exclusively by the sync layer', () {
        expect(PactBreakMapper.toRow(baseBreak())['synced_at'], isNull);
      });
    });

    group('fromRow', () {
      Map<String, dynamic> baseRow() => {
            'id': 'break-1',
            'pact_id': 'pact-1',
            'start_date': startDate.millisecondsSinceEpoch,
            'rationale': 'Recovering from a cold',
            'planned_end_date': null,
            'created_at': null,
            'stopped_at': null,
            'dirty': 1,
            'synced_at': null,
          };

      test('reconstructs required fields correctly', () {
        final b = PactBreakMapper.fromRow(baseRow());

        expect(b.id, equals('break-1'));
        expect(b.pactId, equals('pact-1'));
        expect(b.startDate, equals(startDate));
        expect(b.rationale, equals('Recovering from a cold'));
      });

      test('reconstructs plannedEndDate as null when absent', () {
        expect(PactBreakMapper.fromRow(baseRow()).plannedEndDate, isNull);
      });

      test('reconstructs plannedEndDate when present', () {
        final row = baseRow()..['planned_end_date'] = plannedEndDate.millisecondsSinceEpoch;
        expect(PactBreakMapper.fromRow(row).plannedEndDate, equals(plannedEndDate));
      });

      test('reconstructs createdAt as null when absent', () {
        expect(PactBreakMapper.fromRow(baseRow()).createdAt, isNull);
      });

      test('reconstructs createdAt when present', () {
        final row = baseRow()..['created_at'] = createdAt.millisecondsSinceEpoch;
        expect(PactBreakMapper.fromRow(row).createdAt, equals(createdAt));
      });

      test('reconstructs stoppedAt as null when absent', () {
        expect(PactBreakMapper.fromRow(baseRow()).stoppedAt, isNull);
      });

      test('reconstructs stoppedAt when present', () {
        final row = baseRow()..['stopped_at'] = stoppedAt.millisecondsSinceEpoch;
        expect(PactBreakMapper.fromRow(row).stoppedAt, equals(stoppedAt));
      });

      test('dirty and synced_at columns in row are ignored — not on domain model', () {
        final syncedAt = DateTime(2026, 4, 1, 12, 0);
        final row = baseRow()
          ..['dirty'] = 0
          ..['synced_at'] = syncedAt.millisecondsSinceEpoch;
        expect(() => PactBreakMapper.fromRow(row), returnsNormally);
      });

      test('reconstructs startDate as local-time DateTime (not UTC)', () {
        expect(PactBreakMapper.fromRow(baseRow()).startDate.isUtc, isFalse);
      });
    });

    group('round-trip', () {
      test('open-ended, unstopped break round-trips correctly', () {
        final original = baseBreak();
        final restored = PactBreakMapper.fromRow(PactBreakMapper.toRow(original));
        expect(restored, equals(original));
      });

      test('fixed-end break with createdAt round-trips correctly', () {
        final original = baseBreak(plannedEndDate: plannedEndDate, createdAt: createdAt);
        final restored = PactBreakMapper.fromRow(PactBreakMapper.toRow(original));
        expect(restored, equals(original));
      });

      test('stopped break round-trips correctly', () {
        final original = baseBreak(plannedEndDate: plannedEndDate, stoppedAt: stoppedAt);
        final restored = PactBreakMapper.fromRow(PactBreakMapper.toRow(original));
        expect(restored, equals(original));
      });

      test('local-time startDate preserves hour after round-trip', () {
        final localStart = DateTime(2026, 6, 15, 8, 0);
        final original = PactBreak(
          id: 'break-local',
          pactId: 'pact-local',
          startDate: localStart,
          rationale: 'r',
        );
        final restored = PactBreakMapper.fromRow(PactBreakMapper.toRow(original));
        expect(restored.startDate.hour, equals(localStart.hour));
        expect(restored.startDate.isUtc, isFalse);
      });
    });
  });
}

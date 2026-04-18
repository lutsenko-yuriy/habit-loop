import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_stats.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

Pact _pact({
  DateTime? startDate,
  DateTime? endDate,
  PactStatus status = PactStatus.active,
}) {
  return Pact(
    id: 'pact-1',
    habitName: 'Meditate',
    startDate: startDate ?? DateTime(2026, 4, 1),
    endDate: endDate ?? DateTime(2026, 4, 30),
    showupDuration: const Duration(minutes: 10),
    schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
    status: status,
  );
}

Showup _showup(String id, ShowupStatus status, DateTime scheduledAt) {
  return Showup(
    id: id,
    pactId: 'pact-1',
    scheduledAt: scheduledAt,
    duration: const Duration(minutes: 10),
    status: status,
  );
}

PactStats _computeStats(
  Pact pact,
  List<Showup> showups, {
  int? totalShowups,
}) {
  return PactStats.compute(
    startDate: pact.startDate,
    endDate: pact.endDate,
    showups: showups,
    totalShowups: totalShowups,
  );
}

void main() {
  group('PactStats', () {
    test('counts done, failed and pending showups correctly', () {
      final showups = [
        _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
        _showup('2', ShowupStatus.done, DateTime(2026, 4, 2, 7)),
        _showup('3', ShowupStatus.failed, DateTime(2026, 4, 3, 7)),
        _showup('4', ShowupStatus.pending, DateTime(2026, 4, 4, 7)),
        _showup('5', ShowupStatus.pending, DateTime(2026, 4, 5, 7)),
      ];

      final stats = _computeStats(_pact(), showups);

      expect(stats.showupsDone, 2);
      expect(stats.showupsFailed, 1);
      expect(stats.showupsRemaining, 2);
      expect(stats.totalShowups, 5);
    });

    test('computes current streak of consecutive done showups', () {
      // Streak: Apr 1 done, Apr 2 done, Apr 3 failed → streak breaks
      // Apr 4 done, Apr 5 done → streak = 2
      final showups = [
        _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
        _showup('2', ShowupStatus.done, DateTime(2026, 4, 2, 7)),
        _showup('3', ShowupStatus.failed, DateTime(2026, 4, 3, 7)),
        _showup('4', ShowupStatus.done, DateTime(2026, 4, 4, 7)),
        _showup('5', ShowupStatus.done, DateTime(2026, 4, 5, 7)),
      ];

      final stats = _computeStats(_pact(), showups);

      expect(stats.currentStreak, 2);
    });

    test('streak is zero if last resolved showup was failed', () {
      final showups = [
        _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
        _showup('2', ShowupStatus.failed, DateTime(2026, 4, 2, 7)),
      ];

      final stats = _computeStats(_pact(), showups);

      expect(stats.currentStreak, 0);
    });

    test('streak ignores pending showups at the end', () {
      // done, done, pending → streak = 2 (pending not resolved yet)
      final showups = [
        _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
        _showup('2', ShowupStatus.done, DateTime(2026, 4, 2, 7)),
        _showup('3', ShowupStatus.pending, DateTime(2026, 4, 3, 7)),
      ];

      final stats = _computeStats(_pact(), showups);

      expect(stats.currentStreak, 2);
    });

    test('streak is zero when there are no resolved showups', () {
      final showups = [
        _showup('1', ShowupStatus.pending, DateTime(2026, 4, 1, 7)),
      ];

      final stats = _computeStats(_pact(), showups);

      expect(stats.currentStreak, 0);
    });

    test('streak counts all done showups when no failure', () {
      final showups = [
        _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
        _showup('2', ShowupStatus.done, DateTime(2026, 4, 2, 7)),
        _showup('3', ShowupStatus.done, DateTime(2026, 4, 3, 7)),
      ];

      final stats = _computeStats(_pact(), showups);

      expect(stats.currentStreak, 3);
    });

    test('exposes startDate and endDate from the pact', () {
      final pact = _pact(
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 9, 30),
      );

      final stats = _computeStats(pact, []);

      expect(stats.startDate, DateTime(2026, 4, 1));
      expect(stats.endDate, DateTime(2026, 9, 30));
    });

    test('computes zero counts for empty showup list', () {
      final stats = _computeStats(_pact(), []);

      expect(stats.showupsDone, 0);
      expect(stats.showupsFailed, 0);
      expect(stats.showupsRemaining, 0);
      expect(stats.totalShowups, 0);
      expect(stats.currentStreak, 0);
    });

    test('two PactStats with same fields are equal', () {
      final showups = [
        _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
      ];
      final a = _computeStats(_pact(), showups);
      final b = _computeStats(_pact(), showups);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two PactStats with different fields are not equal', () {
      final a = _computeStats(_pact(), [
        _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
      ]);
      final b = _computeStats(_pact(), [
        _showup('1', ShowupStatus.failed, DateTime(2026, 4, 1, 7)),
      ]);

      expect(a, isNot(equals(b)));
    });

    group('with explicit totalShowups override', () {
      test(
          'totalShowups uses provided value instead of showup list length',
          () {
        // Only 3 showups in the window but the full pact has 30
        final showups = [
          _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
          _showup('2', ShowupStatus.done, DateTime(2026, 4, 2, 7)),
          _showup('3', ShowupStatus.pending, DateTime(2026, 4, 3, 7)),
        ];

        final stats = _computeStats(_pact(), showups, totalShowups: 30);

        expect(stats.totalShowups, 30);
      });

      test(
          'showupsRemaining is derived from totalShowups minus done and failed',
          () {
        // 1 done, 1 failed, total=30 → remaining = 30 - 1 - 1 = 28
        final showups = [
          _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
          _showup('2', ShowupStatus.failed, DateTime(2026, 4, 2, 7)),
          _showup('3', ShowupStatus.pending, DateTime(2026, 4, 3, 7)),
        ];

        final stats = _computeStats(_pact(), showups, totalShowups: 30);

        expect(stats.showupsRemaining, 28);
      });

      test(
          'when totalShowups equals done+failed+pending, remaining equals pending count',
          () {
        // totalShowups == list length: remaining should equal pending count
        final showups = [
          _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
          _showup('2', ShowupStatus.failed, DateTime(2026, 4, 2, 7)),
          _showup('3', ShowupStatus.pending, DateTime(2026, 4, 3, 7)),
        ];

        final stats = _computeStats(_pact(), showups, totalShowups: 3);

        expect(stats.totalShowups, 3);
        expect(stats.showupsRemaining, 1);
      });

      test(
          'without totalShowups override, remaining equals pending count from list',
          () {
        final showups = [
          _showup('1', ShowupStatus.done, DateTime(2026, 4, 1, 7)),
          _showup('2', ShowupStatus.failed, DateTime(2026, 4, 2, 7)),
          _showup('3', ShowupStatus.pending, DateTime(2026, 4, 3, 7)),
        ];

        final stats = _computeStats(_pact(), showups);

        // No override: totalShowups = list length = 3, remaining = pending = 1
        expect(stats.totalShowups, 3);
        expect(stats.showupsRemaining, 1);
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

// Anchor used in tail zone tests:
//   cutoff(7 days) = Jan 7 → tail: days 7-13, non-tail: days 1-6
//   cutoff(3 days) = Jan 11 → tail: days 11-13, non-tail: days 1-10
final _now = DateTime(2024, 1, 14);

Showup _sh(String id, ShowupStatus status, int day, {String? note}) => Showup(
      id: id,
      pactId: 'p',
      scheduledAt: DateTime(2024, 1, day),
      duration: const Duration(minutes: 30),
      status: status,
      note: note,
    );

Showup _done(String id, int day) => _sh(id, ShowupStatus.done, day);
Showup _fail(String id, int day) => _sh(id, ShowupStatus.failed, day);
Showup _noted(String id, int day, {String note = 'great session'}) => _sh(id, ShowupStatus.done, day, note: note);

const _threshold = 10;

// tailPeriodInDays=0 means cutoff=DateTime.now() (2026+), so all Jan-2024
// showups fall outside the tail — equivalent to the old tailSize:0 pattern.
PactTimelineGrouper _g({int threshold = _threshold, int tailPeriodInDays = 0}) =>
    PactTimelineGrouper(groupingThreshold: threshold, noGroupingTailPeriodInDays: tailPeriodInDays);

void main() {
  group('PactTimelineGrouper', () {
    group('empty input', () {
      test('returns empty list for no showups', () {
        expect(_g().group([]), isEmpty);
      });
    });

    group('noted showup', () {
      test('noted showup becomes a NotedShowupMilestone', () {
        final result = _g().group([_noted('s1', 1, note: 'focus')]);
        expect(result, hasLength(1));
        final m = result.single as NotedShowupMilestone;
        expect(m.showupId, 's1');
        expect(m.note, 'focus');
        expect(m.outcome, ShowupStatus.done);
        expect(m.scheduledAt, DateTime(2024, 1, 1));
        expect(m.sortAt, DateTime(2024, 1, 1));
      });

      test('noted showup in the middle of a run separates groups', () {
        final showups = [
          _done('s1', 1),
          _done('s2', 2),
          _noted('s3', 3),
          _done('s4', 4),
          _done('s5', 5),
        ];
        final result = _g().group(showups);
        expect(result, hasLength(3));
        expect(result[0], isA<ShowupGroupMilestone>());
        expect(result[1], isA<NotedShowupMilestone>());
        expect(result[2], isA<ShowupGroupMilestone>());
      });
    });

    group('tail zone — days-based', () {
      test('showup within tail period produces a SingleShowupMilestone', () {
        // Jan 10 is within 7 days of Jan 14 → tail zone
        final result = _g(tailPeriodInDays: 7).group([_done('s1', 10)], now: _now);
        expect(result, hasLength(1));
        final m = result.single as SingleShowupMilestone;
        expect(m.showupId, 's1');
        expect(m.outcome, ShowupStatus.done);
        expect(m.scheduledAt, DateTime(2024, 1, 10));
      });

      test('showup on the cutoff boundary is in the tail zone', () {
        // cutoff = Jan 14 - 7 days = Jan 7; Jan 7 >= Jan 7 → tail
        final result = _g(tailPeriodInDays: 7).group([_done('s1', 7)], now: _now);
        expect(result, hasLength(1));
        expect(result.single, isA<SingleShowupMilestone>());
      });

      test('showup one day before the cutoff is not in the tail zone', () {
        // cutoff = Jan 7; Jan 6 < Jan 7 → non-tail → group (1 < threshold)
        final result = _g(tailPeriodInDays: 7).group([_done('s1', 6)], now: _now);
        expect(result, hasLength(1));
        expect(result.single, isA<ShowupGroupMilestone>());
      });

      test('tail showups produce one SingleShowupMilestone each', () {
        // Jan 11, 12, 13 all within 3 days of Jan 14
        final showups = [_done('s1', 11), _done('s2', 12), _done('s3', 13)];
        final result = _g(tailPeriodInDays: 3).group(showups, now: _now);
        expect(result, hasLength(3));
        for (final m in result) {
          expect(m, isA<SingleShowupMilestone>());
        }
      });

      test('non-tail is grouped/streaked, tail is individual', () {
        // tailPeriodInDays=3, cutoff=Jan 11
        // Non-tail: Jan 1-10 (10 done → streak >= threshold=10)
        // Tail:     Jan 11-13 (3 done → 3 individual)
        final showups = [
          ...List.generate(10, (i) => _done('s$i', i + 1)),
          ...List.generate(3, (i) => _done('t$i', 11 + i)),
        ];
        final result = _g(tailPeriodInDays: 3).group(showups, now: _now);
        expect(result, hasLength(4));
        expect(result.first, isA<ShowupStreakMilestone>());
        expect((result.first as ShowupStreakMilestone).count, 10);
        for (final m in result.skip(1)) {
          expect(m, isA<SingleShowupMilestone>());
        }
      });

      test('noted showup in tail zone is a NotedShowupMilestone, not a SingleShowupMilestone', () {
        final showups = [_done('s1', 10), _noted('s2', 12, note: 'reflection')];
        final result = _g(tailPeriodInDays: 7).group(showups, now: _now);
        expect(result, hasLength(2));
        expect(result[0], isA<SingleShowupMilestone>());
        expect(result[1], isA<NotedShowupMilestone>());
        expect((result[1] as NotedShowupMilestone).note, 'reflection');
      });

      test('tail showup sortAt equals its scheduledAt', () {
        final result = _g(tailPeriodInDays: 7).group([_done('s1', 10)], now: _now);
        expect(result.single.sortAt, DateTime(2024, 1, 10));
      });
    });

    group('short run below threshold (non-tail)', () {
      test('mixed run below threshold collapses into a ShowupGroupMilestone', () {
        final showups = [
          _done('s1', 1),
          _done('s2', 2),
          _done('s3', 3),
          _fail('s4', 4),
          _fail('s5', 5),
        ];
        final result = _g().group(showups);
        expect(result, hasLength(1));
        final m = result.single as ShowupGroupMilestone;
        expect(m.total, 5);
        expect(m.doneCount, 3);
        expect(m.failedCount, 2);
      });

      test('group milestone firstAt and sortAt equal the first showup date', () {
        final showups = [_done('s1', 5), _fail('s2', 6)];
        final result = _g().group(showups);
        final m = result.single as ShowupGroupMilestone;
        expect(m.firstAt, DateTime(2024, 1, 5));
        expect(m.lastAt, DateTime(2024, 1, 6));
        expect(m.sortAt, DateTime(2024, 1, 5));
      });

      test('same-outcome run below threshold is a group, not a streak', () {
        final showups = List.generate(5, (i) => _done('s$i', i + 1));
        final result = _g().group(showups);
        expect(result, hasLength(1));
        expect(result.single, isA<ShowupGroupMilestone>());
        final m = result.single as ShowupGroupMilestone;
        expect(m.total, 5);
        expect(m.doneCount, 5);
        expect(m.failedCount, 0);
      });
    });

    group('single-item streak (threshold=1)', () {
      test('isolated done showup in non-tail with threshold=1 becomes a SingleShowupMilestone', () {
        final showups = [_done('s1', 1), _fail('s2', 2), _done('s3', 3)];
        final result = _g(threshold: 1).group(showups);
        expect(result, hasLength(3));
        expect(result[0], isA<SingleShowupMilestone>());
        expect((result[0] as SingleShowupMilestone).showupId, 's1');
        expect((result[0] as SingleShowupMilestone).outcome, ShowupStatus.done);
        expect(result[1], isA<SingleShowupMilestone>());
        expect((result[1] as SingleShowupMilestone).showupId, 's2');
        expect(result[2], isA<SingleShowupMilestone>());
        expect((result[2] as SingleShowupMilestone).showupId, 's3');
      });

      test('run of 2+ at threshold=1 is still a ShowupStreakMilestone', () {
        final showups = List.generate(3, (i) => _done('s$i', i + 1));
        final result = _g(threshold: 1).group(showups);
        expect(result, hasLength(1));
        expect(result.single, isA<ShowupStreakMilestone>());
        expect((result.single as ShowupStreakMilestone).count, 3);
      });
    });

    group('single-outcome run at or above threshold (non-tail)', () {
      test('run >= threshold becomes a ShowupStreakMilestone, not a group', () {
        final showups = List.generate(12, (i) => _done('s$i', i + 1));
        final result = _g().group(showups);
        expect(result, hasLength(1));
        final m = result.single as ShowupStreakMilestone;
        expect(m.count, 12);
        expect(m.outcome, ShowupStatus.done);
      });

      test('run exactly == threshold becomes a streak', () {
        final showups = List.generate(10, (i) => _fail('s$i', i + 1));
        final result = _g().group(showups);
        expect(result, hasLength(1));
        expect(result.single, isA<ShowupStreakMilestone>());
        expect((result.single as ShowupStreakMilestone).count, 10);
        expect((result.single as ShowupStreakMilestone).outcome, ShowupStatus.failed);
      });

      test('streak milestone has correct firstAt, lastAt, and sortAt', () {
        final showups = List.generate(10, (i) => _done('s$i', i + 1));
        final result = _g().group(showups);
        final m = result.single as ShowupStreakMilestone;
        expect(m.firstAt, DateTime(2024, 1, 1));
        expect(m.lastAt, DateTime(2024, 1, 10));
        expect(m.sortAt, DateTime(2024, 1, 1));
      });
    });

    group('group flush boundary', () {
      test('adding next streak that would push group to >= threshold flushes the group first', () {
        final showups = [
          _done('s1', 1),
          _done('s2', 2),
          _done('s3', 3),
          _done('s4', 4),
          _fail('s5', 5),
          _fail('s6', 6),
          _fail('s7', 7),
          _done('s8', 8),
          _done('s9', 9),
          _done('s10', 10),
          _fail('s11', 11),
          _fail('s12', 12),
        ];
        final result = _g().group(showups);
        expect(result, hasLength(2));
        final g1 = result[0] as ShowupGroupMilestone;
        expect(g1.total, 7);
        expect(g1.doneCount, 4);
        expect(g1.failedCount, 3);
        final g2 = result[1] as ShowupGroupMilestone;
        expect(g2.total, 5);
      });

      test('streak >= threshold after a flush is emitted as a streak, not a group', () {
        final showups = [
          _done('s1', 1),
          _done('s2', 2),
          _done('s3', 3),
          _done('s4', 4),
          _fail('s5', 5),
          _fail('s6', 6),
          _fail('s7', 7),
          ...List.generate(10, (i) => _done('s${8 + i}', 8 + i)),
        ];
        final result = _g().group(showups);
        expect(result, hasLength(2));
        expect(result[0], isA<ShowupGroupMilestone>());
        expect((result[0] as ShowupGroupMilestone).total, 7);
        expect((result[1] as ShowupStreakMilestone).count, 10);
      });

      test('streak that starts a new group after flush is collected as group if short', () {
        final showups = [
          _done('s1', 1),
          _done('s2', 2),
          _done('s3', 3),
          _done('s4', 4),
          _fail('s5', 5),
          _fail('s6', 6),
          _fail('s7', 7),
          _done('s8', 8),
          _done('s9', 9),
          _done('s10', 10),
          _fail('s11', 11),
          _fail('s12', 12),
        ];
        final result = _g().group(showups);
        expect(result, hasLength(2));
        expect((result[0] as ShowupGroupMilestone).total, 7);
        final g2 = result[1] as ShowupGroupMilestone;
        expect(g2.total, 5);
        expect(g2.doneCount, 3);
        expect(g2.failedCount, 2);
      });
    });

    group('pending showups', () {
      test('pending showups are skipped and do not affect grouping', () {
        final showups = [
          _done('s1', 1),
          _sh('s2', ShowupStatus.pending, 2),
          _done('s3', 3),
        ];
        final result = _g().group(showups);
        expect(result, hasLength(1));
        final m = result.single as ShowupGroupMilestone;
        expect(m.total, 2);
        expect(m.doneCount, 2);
      });
    });

    group('sort order', () {
      test('milestones are ordered oldest-first by sortAt', () {
        final showups = [_noted('s1', 1), _done('s2', 2), _done('s3', 3), _noted('s4', 4)];
        final result = _g().group(showups);
        final sortAts = result.map((m) => m.sortAt).toList();
        final sorted = [...sortAts]..sort();
        expect(sortAts, sorted);
      });
    });
  });
}

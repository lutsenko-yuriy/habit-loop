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

// tailPeriodInDays=0 means cutoff=DateTime.now() (2026+), so all Jan-2024
// showups fall outside the tail — equivalent to the old tailSize:0 pattern.
PactTimelineGrouper _g({int tailPeriodInDays = 0}) => PactTimelineGrouper(noGroupingTailPeriodInDays: tailPeriodInDays);

// Convenience: most tests only care about the milestone list, not tailStartIndex.
List<PactTimelineMilestone> _group(PactTimelineGrouper g, List<Showup> showups, {DateTime? now}) =>
    g.group(showups, now: now).milestones;

void main() {
  group('PactTimelineGrouper', () {
    group('empty input', () {
      test('returns empty list for no showups', () {
        expect(_group(_g(), []), isEmpty);
      });
    });

    group('noted showup', () {
      test('noted showup becomes a NotedShowupMilestone', () {
        final result = _group(_g(), [_noted('s1', 1, note: 'focus')]);
        expect(result, hasLength(1));
        final m = result.single as NotedShowupMilestone;
        expect(m.showupId, 's1');
        expect(m.note, 'focus');
        expect(m.outcome, ShowupStatus.done);
        expect(m.scheduledAt, DateTime(2024, 1, 1));
        expect(m.sortAt, DateTime(2024, 1, 1));
      });

      test('noted showup in the middle of a run flushes the streak', () {
        final showups = [
          _done('s1', 1),
          _done('s2', 2),
          _noted('s3', 3),
          _done('s4', 4),
          _done('s5', 5),
        ];
        final result = _group(_g(), showups);
        expect(result, hasLength(3));
        expect(result[0], isA<ShowupStreakMilestone>());
        expect((result[0] as ShowupStreakMilestone).count, 2);
        expect(result[1], isA<NotedShowupMilestone>());
        expect(result[2], isA<ShowupStreakMilestone>());
        expect((result[2] as ShowupStreakMilestone).count, 2);
      });
    });

    group('tail zone — days-based', () {
      test('showup within tail period produces a SingleShowupMilestone', () {
        // Jan 10 is within 7 days of Jan 14 → tail zone
        final result = _group(_g(tailPeriodInDays: 7), [_done('s1', 10)], now: _now);
        expect(result, hasLength(1));
        final m = result.single as SingleShowupMilestone;
        expect(m.showupId, 's1');
        expect(m.outcome, ShowupStatus.done);
        expect(m.scheduledAt, DateTime(2024, 1, 10));
      });

      test('showup on the cutoff boundary is in the tail zone', () {
        // cutoff = midnight(Jan 14) - 7 days = Jan 7 00:00; Jan 7 08:00 >= Jan 7 00:00 → tail
        final result = _group(_g(tailPeriodInDays: 7), [_done('s1', 7)], now: _now);
        expect(result, hasLength(1));
        expect(result.single, isA<SingleShowupMilestone>());
      });

      test('cutoff is calendar-date-based regardless of time of day', () {
        // now at 23:59 vs 00:01 must produce the same tail for Jan 7 (boundary day)
        final showup = _done('s1', 7); // Jan 7 at 00:00
        final nowLate = DateTime(2024, 1, 14, 23, 59);
        final nowEarly = DateTime(2024, 1, 14, 0, 1);
        final resultLate = _group(_g(tailPeriodInDays: 7), [showup], now: nowLate);
        final resultEarly = _group(_g(tailPeriodInDays: 7), [showup], now: nowEarly);
        expect(resultLate.single.runtimeType, resultEarly.single.runtimeType);
      });

      test('showup one day before the cutoff is not in the tail zone', () {
        // cutoff = Jan 7 00:00; Jan 6 < Jan 7 → non-tail → isolated run of 1 → single
        final result = _group(_g(tailPeriodInDays: 7), [_done('s1', 6)], now: _now);
        expect(result, hasLength(1));
        expect(result.single, isA<SingleShowupMilestone>());
      });

      test('tail showups produce one SingleShowupMilestone each', () {
        // Jan 11, 12, 13 all within 3 days of Jan 14
        final showups = [_done('s1', 11), _done('s2', 12), _done('s3', 13)];
        final result = _group(_g(tailPeriodInDays: 3), showups, now: _now);
        expect(result, hasLength(3));
        for (final m in result) {
          expect(m, isA<SingleShowupMilestone>());
        }
      });

      test('non-tail is streaked, tail is individual', () {
        // tailPeriodInDays=3, cutoff=Jan 11
        // Non-tail: Jan 1-10 (10 done → one streak)
        // Tail:     Jan 11-13 (3 done → 3 individual)
        final showups = [
          ...List.generate(10, (i) => _done('s$i', i + 1)),
          ...List.generate(3, (i) => _done('t$i', 11 + i)),
        ];
        final result = _group(_g(tailPeriodInDays: 3), showups, now: _now);
        expect(result, hasLength(4));
        expect(result.first, isA<ShowupStreakMilestone>());
        expect((result.first as ShowupStreakMilestone).count, 10);
        for (final m in result.skip(1)) {
          expect(m, isA<SingleShowupMilestone>());
        }
      });

      test('noted showup in tail zone is a NotedShowupMilestone, not a SingleShowupMilestone', () {
        final showups = [_done('s1', 10), _noted('s2', 12, note: 'reflection')];
        final result = _group(_g(tailPeriodInDays: 7), showups, now: _now);
        expect(result, hasLength(2));
        expect(result[0], isA<SingleShowupMilestone>());
        expect(result[1], isA<NotedShowupMilestone>());
        expect((result[1] as NotedShowupMilestone).note, 'reflection');
      });

      test('tail showup sortAt equals its scheduledAt', () {
        final result = _group(_g(tailPeriodInDays: 7), [_done('s1', 10)], now: _now);
        expect(result.single.sortAt, DateTime(2024, 1, 10));
      });
    });

    group('tailStartIndex', () {
      test('all non-tail → tailStartIndex equals milestones.length', () {
        // With tailPeriodInDays=0, cutoff is now (2026+) → all Jan-2024 showups are non-tail.
        final showups = List.generate(10, (i) => _done('s$i', i + 1));
        final (:milestones, :tailStartIndex) = _g().group(showups);
        expect(tailStartIndex, milestones.length);
      });

      test('all tail → tailStartIndex is 0', () {
        final showups = [_done('s1', 11), _done('s2', 12), _done('s3', 13)];
        final (:milestones, :tailStartIndex) = _g(tailPeriodInDays: 3).group(showups, now: _now);
        expect(tailStartIndex, 0);
        expect(milestones, hasLength(3));
      });

      test('mixed: tailStartIndex points to first tail milestone', () {
        // Non-tail: Jan 1-10 → 1 streak; Tail: Jan 11-13 → 3 singles
        final showups = [
          ...List.generate(10, (i) => _done('s$i', i + 1)),
          ...List.generate(3, (i) => _done('t$i', 11 + i)),
        ];
        final (:milestones, :tailStartIndex) = _g(tailPeriodInDays: 3).group(showups, now: _now);
        expect(tailStartIndex, 1); // 1 non-tail milestone (the streak)
        expect(milestones[tailStartIndex], isA<SingleShowupMilestone>());
      });

      test('tailStartIndex is correct even when non-tail is all SingleShowupMilestone', () {
        // tailPeriodInDays=3, cutoff=Jan 11:
        // Non-tail: Jan 1-10 alternating done/fail → each is a length-1 run → 10 SingleShowupMilestones
        // Tail:     Jan 11-13 done → 3 SingleShowupMilestones
        // All 13 milestones are SingleShowupMilestone; tailStartIndex must be 10, not 0.
        final showups = [
          ...List.generate(10, (i) => i.isEven ? _done('s$i', i + 1) : _fail('s$i', i + 1)),
          ...List.generate(3, (i) => _done('t$i', 11 + i)),
        ];
        final (:milestones, :tailStartIndex) = _g(tailPeriodInDays: 3).group(showups, now: _now);
        // Non-tail: 10 isolated singles → 10 SingleShowupMilestones
        expect(tailStartIndex, 10);
        expect(milestones, hasLength(13));
        expect(milestones[tailStartIndex], isA<SingleShowupMilestone>());
        expect((milestones[tailStartIndex] as SingleShowupMilestone).scheduledAt, DateTime(2024, 1, 11));
      });

      test('empty showups → tailStartIndex is 0', () {
        final (:milestones, :tailStartIndex) = _g().group([]);
        expect(tailStartIndex, 0);
        expect(milestones, isEmpty);
      });
    });

    group('single-item streak', () {
      test('isolated done showup in non-tail becomes a SingleShowupMilestone', () {
        final showups = [_done('s1', 1), _fail('s2', 2), _done('s3', 3)];
        final result = _group(_g(), showups);
        expect(result, hasLength(3));
        expect(result[0], isA<SingleShowupMilestone>());
        expect((result[0] as SingleShowupMilestone).showupId, 's1');
        expect((result[0] as SingleShowupMilestone).outcome, ShowupStatus.done);
        expect(result[1], isA<SingleShowupMilestone>());
        expect((result[1] as SingleShowupMilestone).showupId, 's2');
        expect(result[2], isA<SingleShowupMilestone>());
        expect((result[2] as SingleShowupMilestone).showupId, 's3');
      });

      test('run of 2+ is a ShowupStreakMilestone', () {
        final showups = List.generate(3, (i) => _done('s$i', i + 1));
        final result = _group(_g(), showups);
        expect(result, hasLength(1));
        expect(result.single, isA<ShowupStreakMilestone>());
        expect((result.single as ShowupStreakMilestone).count, 3);
      });
    });

    group('streak milestone', () {
      test('long same-outcome run becomes a single ShowupStreakMilestone', () {
        final showups = List.generate(12, (i) => _done('s$i', i + 1));
        final result = _group(_g(), showups);
        expect(result, hasLength(1));
        final m = result.single as ShowupStreakMilestone;
        expect(m.count, 12);
        expect(m.outcome, ShowupStatus.done);
      });

      test('outcome change flushes the streak', () {
        final showups = List.generate(10, (i) => _fail('s$i', i + 1));
        final result = _group(_g(), showups);
        expect(result, hasLength(1));
        expect(result.single, isA<ShowupStreakMilestone>());
        expect((result.single as ShowupStreakMilestone).count, 10);
        expect((result.single as ShowupStreakMilestone).outcome, ShowupStatus.failed);
      });

      test('streak milestone has correct firstAt, lastAt, and sortAt', () {
        final showups = List.generate(10, (i) => _done('s$i', i + 1));
        final result = _group(_g(), showups);
        final m = result.single as ShowupStreakMilestone;
        expect(m.firstAt, DateTime(2024, 1, 1));
        expect(m.lastAt, DateTime(2024, 1, 10));
        expect(m.sortAt, DateTime(2024, 1, 1));
      });
    });

    group('pending showups', () {
      test('pending showups are skipped and do not affect grouping', () {
        final showups = [
          _done('s1', 1),
          _sh('s2', ShowupStatus.pending, 2),
          _done('s3', 3),
        ];
        final result = _group(_g(), showups);
        expect(result, hasLength(1));
        final m = result.single as ShowupStreakMilestone;
        expect(m.count, 2);
        expect(m.outcome, ShowupStatus.done);
      });
    });

    group('sort order', () {
      test('milestones are ordered oldest-first by sortAt', () {
        final showups = [_noted('s1', 1), _done('s2', 2), _done('s3', 3), _noted('s4', 4)];
        final result = _group(_g(), showups);
        final sortAts = result.map((m) => m.sortAt).toList();
        final sorted = [...sortAts]..sort();
        expect(sortAts, sorted);
      });
    });
  });
}

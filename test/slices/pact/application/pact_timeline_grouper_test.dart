import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
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

    group('groupWithStats', () {
      test('group() and groupWithStats() produce identical milestones and tailStartIndex', () {
        final showups = [
          ...List.generate(10, (i) => _done('s$i', i + 1)),
          ...List.generate(3, (i) => _fail('t$i', 11 + i)),
        ];
        final g = _g(tailPeriodInDays: 3);
        final viaGroup = g.group(showups, now: _now);
        final viaStats = g.groupWithStats(showups, now: _now);

        expect(viaStats.milestones.map((m) => m.runtimeType).toList(), viaGroup.milestones.map((m) => m.runtimeType));
        expect(viaStats.milestones.map((m) => m.sortAt).toList(), viaGroup.milestones.map((m) => m.sortAt));
        expect(viaStats.tailStartIndex, viaGroup.tailStartIndex);
      });

      test('counts done and failed across tail and non-tail zones', () {
        // Non-tail (Jan 1-10): 6 done, 4 failed. Tail (Jan 11-13): 2 done, 1 failed.
        final showups = [
          ...List.generate(6, (i) => _done('d$i', i + 1)),
          ...List.generate(4, (i) => _fail('f$i', 7 + i)),
          _done('t0', 11),
          _done('t1', 12),
          _fail('t2', 13),
        ];
        final result = _g(tailPeriodInDays: 3).groupWithStats(showups, now: _now);
        expect(result.showupsDone, 8);
        expect(result.showupsFailed, 5);
      });

      test('pending showups are excluded from done/failed counts', () {
        final showups = [
          _done('s1', 1),
          _sh('s2', ShowupStatus.pending, 2),
          _fail('s3', 3),
        ];
        final result = _g().groupWithStats(showups);
        expect(result.showupsDone, 1);
        expect(result.showupsFailed, 1);
      });

      test('currentStreak counts the trailing run of done showups', () {
        // Apr-style pattern translated to Jan days: done, done, failed, done, done → streak 2
        final showups = [
          _done('s1', 1),
          _done('s2', 2),
          _fail('s3', 3),
          _done('s4', 4),
          _done('s5', 5),
        ];
        final result = _g().groupWithStats(showups);
        expect(result.currentStreak, 2);
      });

      test('currentStreak is zero when the last resolved showup failed', () {
        final showups = [_done('s1', 1), _fail('s2', 2)];
        final result = _g().groupWithStats(showups);
        expect(result.currentStreak, 0);
      });

      test('currentStreak ignores trailing pending showups', () {
        final showups = [_done('s1', 1), _done('s2', 2), _sh('s3', ShowupStatus.pending, 3)];
        final result = _g().groupWithStats(showups);
        expect(result.currentStreak, 2);
      });

      test('empty input has zero counts and zero streak', () {
        final result = _g().groupWithStats([]);
        expect(result.showupsDone, 0);
        expect(result.showupsFailed, 0);
        expect(result.currentStreak, 0);
        expect(result.milestones, isEmpty);
      });

      test('currentStreak spans a run crossing the tail-zone boundary', () {
        // All done, cutoff mid-run — trailing streak is unaffected by tail bucketing.
        final showups = List.generate(10, (i) => _done('s$i', i + 1));
        final result = _g(tailPeriodInDays: 3).groupWithStats(showups, now: _now);
        expect(result.currentStreak, 10);
      });
    });

    group('breaks (HAB-195 WU5.1)', () {
      PactBreak brk(String id, {required int startDay, int? plannedEndDay, int? stoppedDay}) => PactBreak(
            id: id,
            pactId: 'p',
            startDate: DateTime(2024, 1, startDay),
            rationale: 'rationale-$id',
            plannedEndDate: plannedEndDay != null ? DateTime(2024, 1, plannedEndDay) : null,
            stoppedAt: stoppedDay != null ? DateTime(2024, 1, stoppedDay) : null,
          );

      Showup pending(String id, int day) => _sh(id, ShowupStatus.pending, day);

      test('no breaks produces the same milestones as the showup-only path', () {
        final showups = [_done('s1', 1), _fail('s2', 2)];
        final withBreaks = _g().groupWithStats(showups, breaks: const []);
        final without = _g().groupWithStats(showups);
        expect(withBreaks.milestones.map((m) => m.runtimeType), without.milestones.map((m) => m.runtimeType));
        expect(withBreaks.tailStartIndex, without.tailStartIndex);
      });

      test('an ordinary pending showup (no covering break) is still skipped', () {
        final result = _g().groupWithStats([pending('s1', 1)]);
        expect(result.milestones, isEmpty);
      });

      test('a lone on-break showup (non-tail) becomes a SingleShowupMilestone painted on-break', () {
        final result = _g().groupWithStats([pending('s1', 5)], breaks: [brk('b1', startDay: 1, plannedEndDay: 10)]);
        expect(result.milestones, hasLength(1));
        final m = result.milestones.single as SingleShowupMilestone;
        expect(m.isOnBreak, isTrue);
        expect(m.breakRationale, 'rationale-b1');
        expect(m.outcome, ShowupStatus.pending);
        expect(m.scheduledAt, DateTime(2024, 1, 5));
      });

      test('consecutive on-break showups (non-tail) form a ShowupStreakMilestone', () {
        final showups = [pending('s1', 1), pending('s2', 2), pending('s3', 3)];
        final result = _g().groupWithStats(showups, breaks: [brk('b1', startDay: 1, plannedEndDay: 10)]);
        expect(result.milestones, hasLength(1));
        final m = result.milestones.single as ShowupStreakMilestone;
        expect(m.isOnBreak, isTrue);
        expect(m.breakRationale, 'rationale-b1');
        expect(m.count, 3);
        expect(m.outcome, ShowupStatus.pending);
      });

      test('on-break run does not merge with an adjacent done streak', () {
        final showups = [_done('s1', 1), _done('s2', 2), pending('s3', 3), pending('s4', 4)];
        final result = _g().groupWithStats(showups, breaks: [brk('b1', startDay: 3, plannedEndDay: 10)]);
        expect(result.milestones, hasLength(2));
        expect((result.milestones[0] as ShowupStreakMilestone).isOnBreak, isFalse);
        expect((result.milestones[0] as ShowupStreakMilestone).count, 2);
        expect((result.milestones[1] as ShowupStreakMilestone).isOnBreak, isTrue);
        expect((result.milestones[1] as ShowupStreakMilestone).count, 2);
      });

      test('two adjacent breaks with no gap split into two separate entries', () {
        final showups = [pending('s1', 1), pending('s2', 2)];
        final breaks = [
          brk('b1', startDay: 1, plannedEndDay: 1, stoppedDay: 1),
          brk('b2', startDay: 2, plannedEndDay: 10),
        ];
        final result = _g().groupWithStats(showups, breaks: breaks);
        expect(result.milestones, hasLength(2));
        expect((result.milestones[0] as SingleShowupMilestone).breakRationale, 'rationale-b1');
        expect((result.milestones[1] as SingleShowupMilestone).breakRationale, 'rationale-b2');
      });

      test('on-break showup inside the tail zone is always individual, never part of a streak', () {
        // cutoff(7 days from _now=Jan14) = Jan 7 — Jan 10-12 are all in-tail.
        final showups = [pending('s1', 10), pending('s2', 11), pending('s3', 12)];
        final result = _g(tailPeriodInDays: 7).groupWithStats(
          showups,
          now: _now,
          breaks: [brk('b1', startDay: 1, plannedEndDay: 20)],
        );
        expect(result.milestones, hasLength(3));
        for (final m in result.milestones) {
          expect(m, isA<SingleShowupMilestone>());
          expect((m as SingleShowupMilestone).isOnBreak, isTrue);
        }
      });

      test('does not affect showupsDone/showupsFailed/currentStreak stats', () {
        final showups = [_done('s1', 1), _fail('s2', 2), pending('s3', 3)];
        final breaks = [brk('b1', startDay: 3, plannedEndDay: 4)];
        final result = _g().groupWithStats(showups, breaks: breaks);
        expect(result.showupsDone, 1);
        expect(result.showupsFailed, 1);
        expect(result.currentStreak, 0);
      });

      test('an on-break gap is transparent to the trailing streak, same as any other pending gap', () {
        final showups = [_done('s1', 1), _done('s2', 2), pending('s3', 3), _done('s4', 4), _done('s5', 5)];
        final result = _g().groupWithStats(showups, breaks: [brk('b1', startDay: 3, plannedEndDay: 3)]);
        // s3 is on-break and skips the stats block entirely, so it neither breaks nor
        // advances the running trailing-streak counter — s4/s5 continue incrementing
        // from where s1/s2 left it (pre-existing behaviour for any pending gap).
        expect(result.currentStreak, 4);
      });

      test('group() (not just groupWithStats()) also reflects on-break painting', () {
        final result = _g().group([pending('s1', 5)], breaks: [brk('b1', startDay: 1, plannedEndDay: 10)]);
        expect(result.milestones, hasLength(1));
        expect((result.milestones.single as SingleShowupMilestone).isOnBreak, isTrue);
      });

      group('future dates stay invisible, like any other unresolved pending showup', () {
        // _now = Jan 14. Break spans Jan 10-20, covering yesterday, today, and future days.
        final spanningBreak = brk('b1', startDay: 10, plannedEndDay: 20);

        test('an on-break showup scheduled for today is shown', () {
          final result = _g().groupWithStats([pending('s1', 14)], now: _now, breaks: [spanningBreak]);
          expect(result.milestones, hasLength(1));
          expect((result.milestones.single as SingleShowupMilestone).isOnBreak, isTrue);
        });

        test('an on-break showup scheduled for tomorrow is not shown at all', () {
          final result = _g().groupWithStats([pending('s1', 15)], now: _now, breaks: [spanningBreak]);
          expect(result.milestones, isEmpty);
        });

        test('a past run still streaks together while a same-break future day is excluded entirely', () {
          // Jan 11-13 are non-tail (cutoff=Jan14 with the default 0-day tail) and stream
          // into one streak; Jan 15 is both in the future and, separately, in-tail — either
          // reason alone would keep it out of this streak, but it must not appear at all.
          final showups = [pending('s1', 11), pending('s2', 12), pending('s3', 13), pending('s4', 15)];
          final result = _g().groupWithStats(showups, now: _now, breaks: [spanningBreak]);
          expect(result.milestones, hasLength(1));
          final m = result.milestones.single as ShowupStreakMilestone;
          expect(m.count, 3);
          expect(m.lastAt, DateTime(2024, 1, 13));
        });

        test('future on-break showups do not affect tailStartIndex either', () {
          final showups = [_done('s0', 1), pending('s1', 14), pending('s2', 15)];
          final result = _g(tailPeriodInDays: 7).groupWithStats(showups, now: _now, breaks: [spanningBreak]);
          // cutoff = Jan 7: s0 (Jan 1) is non-tail, s1 (Jan 14, on-break, shown) is in-tail;
          // s2 (Jan 15, future) never enters the milestone list at all.
          expect(result.milestones, hasLength(2));
          expect(result.tailStartIndex, 1);
        });
      });

      group('a manually-resolved future showup is not on-break, but still must not appear', () {
        test('a done showup dated after today never appears on the timeline', () {
          final result = _g().groupWithStats([_sh('s1', ShowupStatus.done, 15)], now: _now);
          expect(result.milestones, isEmpty);
        });

        test('a done showup dated after today still counts toward showupsDone/currentStreak', () {
          final result = _g().groupWithStats([_sh('s1', ShowupStatus.done, 15)], now: _now);
          expect(result.showupsDone, 1);
          expect(result.currentStreak, 1);
        });

        test('a past streak stays intact when a future done showup follows it', () {
          final showups = [_done('s1', 1), _done('s2', 2), _sh('s3', ShowupStatus.done, 15)];
          final result = _g().groupWithStats(showups, now: _now);
          expect(result.milestones, hasLength(1));
          expect((result.milestones.single as ShowupStreakMilestone).count, 2);
        });

        test('today itself still shows, along with an on-break run before it (regression guard)', () {
          // Anchors this exact bug report: today's own entry and a preceding on-break
          // streak must both still render even though a later, manually-resolved
          // future showup is present in the same list.
          final showups = [
            pending('s1', 12),
            pending('s2', 13),
            _done('s3', 14), // today
            _sh('s4', ShowupStatus.done, 16), // future — must be excluded
          ];
          final result = _g().groupWithStats(showups, now: _now, breaks: [brk('b1', startDay: 12, plannedEndDay: 13)]);
          expect(result.milestones, hasLength(2));
          final onBreakRun = result.milestones[0] as ShowupStreakMilestone;
          expect(onBreakRun.isOnBreak, isTrue);
          expect(onBreakRun.count, 2);
          final todayEntry = result.milestones[1] as SingleShowupMilestone;
          expect(todayEntry.isOnBreak, isFalse);
          expect(todayEntry.outcome, ShowupStatus.done);
          expect(todayEntry.scheduledAt, DateTime(2024, 1, 14));
        });
      });
    });
  });
}

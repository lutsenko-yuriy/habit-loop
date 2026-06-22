import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';

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
const _grouper = PactTimelineGrouper();

void main() {
  group('PactTimelineGrouper', () {
    group('empty input', () {
      test('returns empty list for no showups', () {
        expect(_grouper.group([], groupingThreshold: _threshold), isEmpty);
      });
    });

    group('noted showup', () {
      test('noted showup becomes a NotedShowupMilestone', () {
        final result = _grouper.group(
          [_noted('s1', 1, note: 'focus')],
          groupingThreshold: _threshold,
          noGroupingTailSize: 0,
        );
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
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        expect(result, hasLength(3));
        expect(result[0], isA<ShowupGroupMilestone>());
        expect(result[1], isA<NotedShowupMilestone>());
        expect(result[2], isA<ShowupGroupMilestone>());
      });
    });

    group('tail zone defaults', () {
      test('single done showup (tail zone by default) becomes a count=1 streak with singleShowupId', () {
        final result = _grouper.group([_done('s1', 1)], groupingThreshold: _threshold);
        expect(result, hasLength(1));
        final m = result.single as ShowupStreakMilestone;
        expect(m.count, 1);
        expect(m.outcome, ShowupStatus.done);
        expect(m.singleShowupId, 's1');
      });

      test('noGroupingTailSize defaults to groupingThreshold when null', () {
        // 20 done; tail defaults to threshold=10 → same as explicit tailSize=10
        final showups = List.generate(20, (i) => _done('s$i', i + 1));
        final withDefault = _grouper.group(showups, groupingThreshold: _threshold);
        final withExplicit = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 10);
        expect(withDefault.length, withExplicit.length);
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
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        expect(result, hasLength(1));
        final m = result.single as ShowupGroupMilestone;
        expect(m.total, 5);
        expect(m.doneCount, 3);
        expect(m.failedCount, 2);
      });

      test('group milestone firstAt and sortAt equal the first showup date', () {
        final showups = [_done('s1', 5), _fail('s2', 6)];
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        final m = result.single as ShowupGroupMilestone;
        expect(m.firstAt, DateTime(2024, 1, 5));
        expect(m.lastAt, DateTime(2024, 1, 6));
        expect(m.sortAt, DateTime(2024, 1, 5));
      });

      test('same-outcome run below threshold is a group, not a streak', () {
        final showups = List.generate(5, (i) => _done('s$i', i + 1));
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        expect(result, hasLength(1));
        expect(result.single, isA<ShowupGroupMilestone>());
        final m = result.single as ShowupGroupMilestone;
        expect(m.total, 5);
        expect(m.doneCount, 5);
        expect(m.failedCount, 0);
      });
    });

    group('single-outcome run at or above threshold (non-tail)', () {
      test('run >= threshold becomes a ShowupStreakMilestone, not a group', () {
        final showups = List.generate(12, (i) => _done('s$i', i + 1));
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        expect(result, hasLength(1));
        final m = result.single as ShowupStreakMilestone;
        expect(m.count, 12);
        expect(m.outcome, ShowupStatus.done);
        expect(m.singleShowupId, isNull);
      });

      test('run exactly == threshold becomes a streak', () {
        final showups = List.generate(10, (i) => _fail('s$i', i + 1));
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        expect(result, hasLength(1));
        expect(result.single, isA<ShowupStreakMilestone>());
        expect((result.single as ShowupStreakMilestone).count, 10);
        expect((result.single as ShowupStreakMilestone).outcome, ShowupStatus.failed);
      });

      test('streak milestone has correct firstAt, lastAt, and sortAt', () {
        final showups = List.generate(10, (i) => _done('s$i', i + 1));
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        final m = result.single as ShowupStreakMilestone;
        expect(m.firstAt, DateTime(2024, 1, 1));
        expect(m.lastAt, DateTime(2024, 1, 10));
        expect(m.sortAt, DateTime(2024, 1, 1));
      });
    });

    group('tail zone', () {
      test('tail showups produce individual count=1 streaks with singleShowupId', () {
        // 3 done in tail zone → 3 individual streaks, not a group
        final showups = List.generate(3, (i) => _done('s$i', i + 1));
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 3);
        expect(result, hasLength(3));
        for (var i = 0; i < result.length; i++) {
          final m = result[i] as ShowupStreakMilestone;
          expect(m.count, 1);
          expect(m.singleShowupId, 's$i');
        }
      });

      test('non-tail is grouped, tail is individual', () {
        // 10 done (non-tail, >= threshold → streak) + 10 done (tail → 10 individual count=1 streaks)
        final showups = List.generate(20, (i) => _done('s$i', i + 1));
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 10);

        // Non-tail: 1 streak (count=10)
        final head = result.first as ShowupStreakMilestone;
        expect(head.count, 10);
        expect(head.singleShowupId, isNull);

        // Tail: 10 individual count=1 streaks
        expect(result, hasLength(11));
        for (final m in result.skip(1)) {
          final streak = m as ShowupStreakMilestone;
          expect(streak.count, 1);
          expect(streak.singleShowupId, isNotNull);
        }
      });

      test('noted showup in tail zone is a NotedShowupMilestone, not a streak', () {
        final showups = [_done('s1', 1), _noted('s2', 2, note: 'reflection')];
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 2);
        expect(result, hasLength(2));
        expect(result[0], isA<ShowupStreakMilestone>());
        expect(result[1], isA<NotedShowupMilestone>());
        expect((result[1] as NotedShowupMilestone).note, 'reflection');
      });

      test('tail showup sortAt equals its scheduledAt', () {
        final showups = [_done('s1', 7)];
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 1);
        expect(result.single.sortAt, DateTime(2024, 1, 7));
      });
    });

    group('group flush boundary', () {
      test('adding next streak that would push group to >= threshold flushes the group first', () {
        // streaks: 4 done, 3 failed (group=7), then 5 done → 7+5=12 >= 10 → flush group, new group=5
        // then 2 failed → 5+2=7 < 10 → add → group=7; end → flush group
        final showups = [
          _done('s1', 1), _done('s2', 2), _done('s3', 3), _done('s4', 4), // streak 4
          _fail('s5', 5), _fail('s6', 6), _fail('s7', 7), // streak 3 → group total=7
          _done('s8', 8), _done('s9', 9), _done('s10', 10), // streak 3 → 7+3=10 >= 10 → flush
          _fail('s11', 11), _fail('s12', 12), // streak 2 → group=3+2=5; flush at end
        ];
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        expect(result, hasLength(2));
        final g1 = result[0] as ShowupGroupMilestone;
        expect(g1.total, 7);
        expect(g1.doneCount, 4);
        expect(g1.failedCount, 3);
        final g2 = result[1] as ShowupGroupMilestone;
        expect(g2.total, 5);
      });

      test('streak >= threshold after a flush is emitted as a streak, not a group', () {
        // group=7 (4+3), then 10 done → flush group, 10 >= threshold → emit as streak
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
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        expect(result, hasLength(2));
        expect(result[0], isA<ShowupGroupMilestone>());
        expect((result[0] as ShowupGroupMilestone).total, 7);
        final streak = result[1] as ShowupStreakMilestone;
        expect(streak.count, 10);
        expect(streak.singleShowupId, isNull);
      });

      test('streak that starts a new group after flush is collected as group if short', () {
        // 4+3=7, then 3 done → 7+3=10 >= threshold → flush group(7), 3<10 → new group
        // 2 failed → 3+2=5 < 10 → add to group; end → flush group(5)
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
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        expect(result, hasLength(2));
        final g1 = result[0] as ShowupGroupMilestone;
        expect(g1.total, 7);
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
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        // s1 and s3 both done, pending is skipped → one group of 2
        expect(result, hasLength(1));
        final m = result.single as ShowupGroupMilestone;
        expect(m.total, 2);
        expect(m.doneCount, 2);
      });
    });

    group('sort order', () {
      test('milestones are ordered oldest-first by sortAt', () {
        final showups = [
          _noted('s1', 1),
          _done('s2', 2),
          _done('s3', 3),
          _noted('s4', 4),
        ];
        final result = _grouper.group(showups, groupingThreshold: _threshold, noGroupingTailSize: 0);
        final sortAts = result.map((m) => m.sortAt).toList();
        final sorted = [...sortAts]..sort();
        expect(sortAts, sorted);
      });
    });
  });
}

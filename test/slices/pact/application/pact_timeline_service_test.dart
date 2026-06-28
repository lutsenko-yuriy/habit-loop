import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_showup_cache.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_grouper.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_milestone.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

const _schedule = DailySchedule(timeOfDay: Duration(hours: 8));
final _start = DateTime(2024, 1, 1);
final _end = DateTime(2024, 3, 31);
final _created = DateTime(2024, 1, 1, 9, 0);
final _now = DateTime(2024, 2, 15, 12, 0);

Pact _pact({
  String id = 'p1',
  PactStatus status = PactStatus.active,
  DateTime? createdAt,
  DateTime? stoppedAt,
  String? stopReason,
}) =>
    Pact(
      id: id,
      habitName: 'Meditate',
      startDate: _start,
      endDate: _end,
      showupDuration: const Duration(minutes: 30),
      schedule: _schedule,
      status: status,
      createdAt: createdAt,
      stoppedAt: stoppedAt,
      stopReason: stopReason,
    );

Showup _showup(String id, DateTime at, {ShowupStatus status = ShowupStatus.done}) => Showup(
      id: id,
      pactId: 'p1',
      scheduledAt: at,
      duration: const Duration(minutes: 30),
      status: status,
    );

PactTimelineService _service({
  List<Pact>? pacts,
  List<Showup>? showups,
  PactTimelineGrouper? grouper,
  PactShowupCache? cache,
}) =>
    PactTimelineService(
      pactRepository: InMemoryPactRepository(pacts),
      showupRepository: InMemoryShowupRepository(showups),
      grouper: grouper ?? const PactTimelineGrouper(groupingThreshold: 10),
      cache: cache ?? PactShowupCache(),
    );

void main() {
  group('PactTimelineService — anchor start', () {
    test('anchorStart uses pact.createdAt when set', () async {
      final svc = _service(pacts: [_pact(createdAt: _created)]);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      expect(page.anchorStart.sortAt, _created);
      expect(page.anchorStart.habitName, 'Meditate');
      expect(page.anchorStart.schedule, _schedule);
      expect(page.anchorStart.plannedEndDate, _end);
    });

    test('anchorStart falls back to startDate when createdAt is null', () async {
      final svc = _service(pacts: [_pact()]);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      expect(page.anchorStart.sortAt, _start);
    });
  });

  group('PactTimelineService — anchor end (active pact)', () {
    test('anchorEnd is CurrentStateMilestone for active pact', () async {
      final pending = _showup('s1', DateTime(2024, 2, 15, 8), status: ShowupStatus.pending);
      final svc = _service(pacts: [_pact()], showups: [pending]);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      final anchor = page.anchorEnd as CurrentStateMilestone;
      expect(anchor.sortAt, _now);
      expect(anchor.plannedEndDate, _end);
    });

    test('nextScheduledAt is the earliest pending showup date', () async {
      final done = _showup('s1', DateTime(2024, 2, 10, 8));
      final pending = _showup('s2', DateTime(2024, 2, 15, 8), status: ShowupStatus.pending);
      final pending2 = _showup('s3', DateTime(2024, 2, 16, 8), status: ShowupStatus.pending);
      final svc = _service(pacts: [_pact()], showups: [done, pending, pending2]);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      final anchor = page.anchorEnd as CurrentStateMilestone;
      expect(anchor.nextScheduledAt, DateTime(2024, 2, 15, 8));
      // 91 total daily slots (Jan–Mar 2024) minus 1 done = 90 remaining.
      expect(anchor.showupsRemaining, 90);
    });

    test('nextScheduledAt is null when no pending showups', () async {
      final done = _showup('s1', DateTime(2024, 2, 10, 8));
      final svc = _service(pacts: [_pact()], showups: [done]);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      final anchor = page.anchorEnd as CurrentStateMilestone;
      expect(anchor.nextScheduledAt, isNull);
      // 91 total daily slots (Jan–Mar 2024) minus 1 done = 90 remaining.
      expect(anchor.showupsRemaining, 90);
    });
  });

  group('PactTimelineService — anchor end (concluded pact)', () {
    test('anchorEnd is PactConcludedMilestone for stopped pact', () async {
      final stopped = _pact(
        status: PactStatus.stopped,
        stoppedAt: DateTime(2024, 2, 10),
        stopReason: 'Not for me',
      );
      final svc = _service(pacts: [stopped]);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      final anchor = page.anchorEnd as PactConcludedMilestone;
      expect(anchor.concludedAt, DateTime(2024, 2, 10));
      expect(anchor.finalStatus, PactStatus.stopped);
      expect(anchor.note, 'Not for me');
    });

    test('anchorEnd for completed pact uses endDate as concludedAt', () async {
      final completed = _pact(status: PactStatus.completed);
      final svc = _service(pacts: [completed]);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      final anchor = page.anchorEnd as PactConcludedMilestone;
      expect(anchor.concludedAt, _end);
      expect(anchor.finalStatus, PactStatus.completed);
      expect(anchor.note, isNull);
    });
  });

  group('PactTimelineService — milestones', () {
    test('all showup milestones are returned (no windowing)', () async {
      final showups = List.generate(
        25,
        (i) => Showup(
          id: 's$i',
          pactId: 'p1',
          scheduledAt: DateTime(2024, 1, i + 1, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
          note: 'n$i',
        ),
      );
      final svc = _service(pacts: [_pact()], showups: showups);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      expect(page.milestones, hasLength(25));
    });

    test('milestones are oldest-first', () async {
      final showups = List.generate(
        5,
        (i) => Showup(
          id: 's$i',
          pactId: 'p1',
          scheduledAt: DateTime(2024, 1, i + 1, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
          note: 'n$i',
        ),
      );
      final svc = _service(pacts: [_pact()], showups: showups);
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      final sortAts = page.milestones.map((m) => m.sortAt).toList();
      expect(sortAts, equals([...sortAts]..sort()));
    });
  });

  group('PactTimelineService — injected grouper', () {
    test('service delegates to the injected grouper', () async {
      // threshold=10, tailPeriodInDays=3, now=Jan 13 → cutoff=Jan 10
      // Non-tail: Jan 1-9 (9 done, 9 < threshold → 1 group) + tail: Jan 10-12 (3 individual) = 4
      final showups = List.generate(12, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final svc = _service(
        pacts: [_pact()],
        showups: showups,
        grouper: const PactTimelineGrouper(groupingThreshold: 10, noGroupingTailPeriodInDays: 3),
      );
      final page = await svc.loadAll(pactId: 'p1', now: DateTime(2024, 1, 13));
      expect(page.milestones, hasLength(4));
      // tailStartIndex must equal the non-tail milestone count (1 group), not 0 or 4.
      expect(page.tailStartIndex, 1);
    });
  });

  group('PactTimelineService — showup cache', () {
    test('populates cache after DB load', () async {
      final cache = PactShowupCache();
      final svc = _service(
        pacts: [_pact()],
        showups: [_showup('s1', DateTime(2024, 1, 5, 8))],
        cache: cache,
      );
      await svc.loadAll(pactId: 'p1', now: _now);
      expect(cache.get('p1'), isNotNull);
      expect(cache.get('p1'), hasLength(1));
    });

    test('uses cached showups instead of DB on second call', () async {
      final cache = PactShowupCache();
      // Pre-populate cache with 1 showup.
      cache.populate('p1', [_showup('s1', DateTime(2024, 1, 5, 8))]);
      // DB has 2 different showups — service must ignore them.
      final svc = _service(
        pacts: [_pact()],
        showups: [_showup('s2', DateTime(2024, 1, 6, 8)), _showup('s3', DateTime(2024, 1, 7, 8))],
        cache: cache,
      );
      final page = await svc.loadAll(pactId: 'p1', now: _now);
      expect(page.milestones, hasLength(1));
    });
  });
}

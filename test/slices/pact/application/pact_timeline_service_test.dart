import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_timeline_config.dart';
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

PactTimelineConfig _config({int first = 20, int nth = 10}) => PactTimelineConfig(
      enabled: true,
      milestoneGroupingThreshold: 10,
      noGroupingTailSize: 0,
      firstPageSize: first,
      nthPageSize: nth,
    );

PactTimelineService _service({
  List<Pact>? pacts,
  List<Showup>? showups,
  PactTimelineGrouper? grouper,
}) =>
    PactTimelineService(
      pactRepository: InMemoryPactRepository(pacts),
      showupRepository: InMemoryShowupRepository(showups),
      grouper: grouper ?? const PactTimelineGrouper(groupingThreshold: 10),
    );

void main() {
  group('PactTimelineService — anchor start', () {
    test('anchorStart uses pact.createdAt when set', () async {
      final svc = _service(pacts: [_pact(createdAt: _created)]);
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 1, config: _config(), now: _now);
      expect(page.anchorStart.sortAt, _created);
      expect(page.anchorStart.habitName, 'Meditate');
      expect(page.anchorStart.schedule, _schedule);
      expect(page.anchorStart.plannedEndDate, _end);
    });

    test('anchorStart falls back to startDate when createdAt is null', () async {
      final svc = _service(pacts: [_pact()]);
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 1, config: _config(), now: _now);
      expect(page.anchorStart.sortAt, _start);
    });
  });

  group('PactTimelineService — anchor end (active pact)', () {
    test('anchorEnd is CurrentStateMilestone for active pact', () async {
      final pending = _showup('s1', DateTime(2024, 2, 15, 8), status: ShowupStatus.pending);
      final svc = _service(pacts: [_pact()], showups: [pending]);
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 1, config: _config(), now: _now);
      final anchor = page.anchorEnd as CurrentStateMilestone;
      expect(anchor.sortAt, _now);
      expect(anchor.plannedEndDate, _end);
    });

    test('nextScheduledAt is the first pending showup date', () async {
      final done = _showup('s1', DateTime(2024, 2, 10, 8));
      final pending = _showup('s2', DateTime(2024, 2, 15, 8), status: ShowupStatus.pending);
      final pending2 = _showup('s3', DateTime(2024, 2, 16, 8), status: ShowupStatus.pending);
      final svc = _service(pacts: [_pact()], showups: [done, pending, pending2]);
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 1, config: _config(), now: _now);
      final anchor = page.anchorEnd as CurrentStateMilestone;
      expect(anchor.nextScheduledAt, DateTime(2024, 2, 15, 8));
      expect(anchor.showupsRemaining, 2);
    });

    test('nextScheduledAt is null when no pending showups', () async {
      final done = _showup('s1', DateTime(2024, 2, 10, 8));
      final svc = _service(pacts: [_pact()], showups: [done]);
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 1, config: _config(), now: _now);
      final anchor = page.anchorEnd as CurrentStateMilestone;
      expect(anchor.nextScheduledAt, isNull);
      expect(anchor.showupsRemaining, 0);
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
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 1, config: _config(), now: _now);
      final anchor = page.anchorEnd as PactConcludedMilestone;
      expect(anchor.concludedAt, DateTime(2024, 2, 10));
      expect(anchor.finalStatus, PactStatus.stopped);
      expect(anchor.note, 'Not for me');
    });

    test('anchorEnd for completed pact uses endDate as concludedAt', () async {
      final completed = _pact(status: PactStatus.completed);
      final svc = _service(pacts: [completed]);
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 1, config: _config(), now: _now);
      final anchor = page.anchorEnd as PactConcludedMilestone;
      expect(anchor.concludedAt, _end);
      expect(anchor.finalStatus, PactStatus.completed);
      expect(anchor.note, isNull);
    });
  });

  group('PactTimelineService — pagination', () {
    test('page 1 with few milestones: hasMoreOlder=false, all milestones returned', () async {
      // tail=0 sentinel → defaults to threshold=10; all 3 showups go into tail zone → 3 individual items
      final showups = List.generate(3, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final svc = _service(pacts: [_pact()], showups: showups);
      final page = await svc.loadPage(
        pactId: 'p1',
        pageNumber: 1,
        config: _config(first: 20, nth: 10),
        now: _now,
      );
      expect(page.hasMoreOlder, isFalse);
      expect(page.loadedPageCount, 1);
      expect(page.milestones, hasLength(3)); // 3 in tail zone → 3 SingleShowupMilestone
    });

    test('page 1 with more milestones than firstPageSize: hasMoreOlder=true, shows last firstPageSize', () async {
      // Each noted showup is a separate milestone → 25 milestones total
      final showups = List.generate(
        25,
        (i) => Showup(
          id: 's$i',
          pactId: 'p1',
          scheduledAt: DateTime(2024, 1, i + 1, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
          note: 'note $i',
        ),
      );
      final svc = _service(pacts: [_pact()], showups: showups);
      final page = await svc.loadPage(
        pactId: 'p1',
        pageNumber: 1,
        config: _config(first: 20, nth: 10),
        now: _now,
      );
      expect(page.hasMoreOlder, isTrue);
      expect(page.milestones, hasLength(20));
      // The most recent 20 milestones should be the last 20 by sortAt
      final firstVisible = page.milestones.first.sortAt;
      expect(firstVisible, DateTime(2024, 1, 6, 8)); // day 6 is the 6th = index 5 (0-based)
    });

    test('page 2 reveals older milestones', () async {
      final showups = List.generate(
        25,
        (i) => Showup(
          id: 's$i',
          pactId: 'p1',
          scheduledAt: DateTime(2024, 1, i + 1, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
          note: 'note $i',
        ),
      );
      final svc = _service(pacts: [_pact()], showups: showups);
      final page2 = await svc.loadPage(
        pactId: 'p1',
        pageNumber: 2,
        config: _config(first: 20, nth: 5),
        now: _now,
      );
      // page 1 shows last 20, page 2 shows last 25 = all (20+5=25)
      expect(page2.hasMoreOlder, isFalse);
      expect(page2.milestones, hasLength(25));
      expect(page2.loadedPageCount, 2);
    });

    test('loadedPageCount reflects the pageNumber argument', () async {
      final svc = _service(pacts: [_pact()], showups: []);
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 3, config: _config(), now: _now);
      expect(page.loadedPageCount, 3);
    });
  });

  group('PactTimelineService — page size derivation', () {
    test('when only nthPageSize is set (first=0): firstPageSize = 2 × nth', () async {
      // 15 noted milestones; first=0, nth=5 → derived first=10 → hasMoreOlder=true
      final showups = List.generate(
        15,
        (i) => Showup(
          id: 's$i',
          pactId: 'p1',
          scheduledAt: DateTime(2024, 1, i + 1, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
          note: 'n',
        ),
      );
      final svc = _service(pacts: [_pact()], showups: showups);
      final page = await svc.loadPage(
        pactId: 'p1',
        pageNumber: 1,
        config: _config(first: 0, nth: 5),
        now: _now,
      );
      expect(page.milestones, hasLength(10)); // derived first = 2×5
      expect(page.hasMoreOlder, isTrue);
    });

    test('when only firstPageSize is set (nth=0): nthPageSize = first / 2', () async {
      // 25 noted milestones; first=20, nth=0 → derived nth=10; page2 shows 20+10=30 but only 25 → all
      final showups = List.generate(
        25,
        (i) => Showup(
          id: 's$i',
          pactId: 'p1',
          scheduledAt: DateTime(2024, 1, i + 1, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
          note: 'n',
        ),
      );
      final svc = _service(pacts: [_pact()], showups: showups);
      final page2 = await svc.loadPage(
        pactId: 'p1',
        pageNumber: 2,
        config: _config(first: 20, nth: 0),
        now: _now,
      );
      // derived nth = 10; totalVisible = 20 + 10 = 30 > 25 → shows all 25
      expect(page2.milestones, hasLength(25));
      expect(page2.hasMoreOlder, isFalse);
    });

    test('when both are 0: defaults to first=20, nth=10', () async {
      final showups = List.generate(
        25,
        (i) => Showup(
          id: 's$i',
          pactId: 'p1',
          scheduledAt: DateTime(2024, 1, i + 1, 8),
          duration: const Duration(minutes: 30),
          status: ShowupStatus.done,
          note: 'n',
        ),
      );
      final svc = _service(pacts: [_pact()], showups: showups);
      final page = await svc.loadPage(
        pactId: 'p1',
        pageNumber: 1,
        config: _config(first: 0, nth: 0),
        now: _now,
      );
      expect(page.milestones, hasLength(20)); // default first=20
      expect(page.hasMoreOlder, isTrue);
    });
  });

  group('PactTimelineService — injected grouper', () {
    test('service uses the grouper provided at construction; tail=3 → 3 individual + 1 group', () async {
      // 12 done showups; grouper with threshold=10, tailSize=3
      // Non-tail=9 → 1 group (below threshold); tail=3 → 3 SingleShowupMilestone; total 4
      final showups = List.generate(12, (i) => _showup('s$i', DateTime(2024, 1, i + 1, 8)));
      final svc = _service(
        pacts: [_pact()],
        showups: showups,
        grouper: const PactTimelineGrouper(groupingThreshold: 10, noGroupingTailSize: 3),
      );
      final page = await svc.loadPage(
        pactId: 'p1',
        pageNumber: 1,
        config: _config(first: 20, nth: 10),
        now: _now,
      );
      expect(page.milestones, hasLength(4)); // 1 group + 3 individual
    });
  });

  group('PactTimelineService — milestones order', () {
    test('milestones are oldest-first within the visible window', () async {
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
      final page = await svc.loadPage(pactId: 'p1', pageNumber: 1, config: _config(), now: _now);
      final sortAts = page.milestones.map((m) => m.sortAt).toList();
      expect(sortAts, equals([...sortAts]..sort()));
    });
  });
}

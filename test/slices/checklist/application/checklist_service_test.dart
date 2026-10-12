import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';
import 'package:habit_loop/slices/checklist/application/checklist_service.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/checklister/fake_checklister_gateway.dart';

Pact _pact(String id, {PactStatus status = PactStatus.active}) => Pact(
      id: id,
      habitName: 'Meditate',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 9, 1),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: status,
    );

SelectionCallback _selected(String pactId, String id, String name) => SelectionCallback(
      pactId: pactId,
      status: ChecklisterCallbackStatus.selected,
      checklistId: id,
      checklistName: name,
    );

SelectionCallback _status(String pactId, ChecklisterCallbackStatus s) => SelectionCallback(pactId: pactId, status: s);

void main() {
  final now = DateTime(2026, 5, 10, 12);
  late InMemoryPactChecklistLinkRepository links;
  late InMemoryPactRepository pacts;
  late FakeChecklisterGateway gateway;
  late FakeAnalyticsService analytics;
  late ChecklistService service;

  setUp(() {
    links = InMemoryPactChecklistLinkRepository();
    pacts = InMemoryPactRepository([_pact('p1'), _pact('stopped', status: PactStatus.stopped)]);
    gateway = FakeChecklisterGateway();
    analytics = FakeAnalyticsService();
    service = ChecklistService(
      linkRepository: links,
      pactRepository: pacts,
      gateway: gateway,
      analytics: analytics,
      now: () => now,
    );
  });

  PactChecklistLink link(String id, String name, {DateTime? at}) =>
      PactChecklistLink(pactId: 'p1', checklistId: id, checklistName: name, linkedAt: at ?? now);

  group('startSelection', () {
    test('launches select with the pact\'s selected-callback URL and logs mode=select when unlinked', () async {
      expect(await service.startSelection('p1'), isTrue);

      final callback = ChecklisterLinks.selectedCallback('p1').toString();
      expect(gateway.launchedUrls.single, ChecklisterLinks.selectUri(callback));
      final e = analytics.loggedEvents.single as PactChecklistSelectionStartedEvent;
      expect(e.pactId, 'p1');
      expect(e.mode, 'select');
    });

    test('logs mode=change when a link already exists (derived from the repository)', () async {
      await links.upsert(link('c1', 'Morning'));
      await service.startSelection('p1');
      expect((analytics.loggedEvents.single as PactChecklistSelectionStartedEvent).mode, 'change');
    });

    test('returns false, no event, when Checklister cannot be opened', () async {
      gateway.canLaunch = false;
      expect(await service.startSelection('p1'), isFalse);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('does nothing for a pact that is not active', () async {
      expect(await service.startSelection('stopped'), isFalse);
      expect(gateway.launchedUrls, isEmpty);
      expect(analytics.loggedEvents, isEmpty);
    });
  });

  group('applySelection', () {
    test('selected on an unlinked active pact: persists the link, logs linked mode=select', () async {
      final outcome = await service.applySelection(_selected('p1', 'c1', 'Morning'));

      expect(outcome, SelectionOutcome.linked);
      final saved = (await links.getForPact('p1'))!;
      expect([saved.checklistId, saved.checklistName, saved.linkedAt], ['c1', 'Morning', now]);
      final e = analytics.loggedEvents.single as PactChecklistLinkedEvent;
      expect([e.pactId, e.mode], ['p1', 'select']);
    });

    test('selected a different checklist: replaces the link, logs mode=change', () async {
      await links.upsert(link('c1', 'Morning', at: DateTime(2026, 5, 1)));

      final outcome = await service.applySelection(_selected('p1', 'c2', 'Evening'));

      expect(outcome, SelectionOutcome.linked);
      expect((await links.getForPact('p1'))!.checklistId, 'c2');
      expect((analytics.loggedEvents.single as PactChecklistLinkedEvent).mode, 'change');
    });

    test('idempotent: re-delivered identical selection changes nothing and logs nothing', () async {
      final original = link('c1', 'Morning', at: DateTime(2026, 5, 1));
      await links.upsert(original);

      final outcome = await service.applySelection(_selected('p1', 'c1', 'Morning'));

      expect(outcome, SelectionOutcome.unchanged);
      expect(await links.getForPact('p1'), original);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('same checklist renamed in Checklister: updates the name, keeps linkedAt, logs nothing', () async {
      await links.upsert(link('c1', 'Morning', at: DateTime(2026, 5, 1)));

      final outcome = await service.applySelection(_selected('p1', 'c1', 'Morning v2'));

      expect(outcome, SelectionOutcome.unchanged);
      final saved = (await links.getForPact('p1'))!;
      expect(saved.checklistName, 'Morning v2');
      expect(saved.linkedAt, DateTime(2026, 5, 1));
      expect(analytics.loggedEvents, isEmpty);
    });

    test('stale callback: pact no longer active is ignored', () async {
      final outcome = await service.applySelection(_selected('stopped', 'c1', 'Morning'));
      expect(outcome, SelectionOutcome.ignored);
      expect(await links.getForPact('stopped'), isNull);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('stale callback: unknown pact is ignored', () async {
      expect(await service.applySelection(_selected('ghost', 'c1', 'Morning')), SelectionOutcome.ignored);
      expect(await links.getForPact('ghost'), isNull);
    });

    test('selected without checklist id or name is ignored', () async {
      expect(
        await service.applySelection(_status('p1', ChecklisterCallbackStatus.selected)),
        SelectionOutcome.ignored,
      );
      expect(await links.getForPact('p1'), isNull);
    });

    test('cancelled leaves an existing link alone', () async {
      final original = link('c1', 'Morning');
      await links.upsert(original);

      expect(
          await service.applySelection(_status('p1', ChecklisterCallbackStatus.cancelled)), SelectionOutcome.cancelled);
      expect(await links.getForPact('p1'), original);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('error reports noChecklists and changes nothing', () async {
      expect(
          await service.applySelection(_status('p1', ChecklisterCallbackStatus.error)), SelectionOutcome.noChecklists);
      expect(await links.getForPact('p1'), isNull);
      expect(analytics.loggedEvents, isEmpty);
    });
  });

  group('unlink', () {
    test('deletes the link and logs days_linked', () async {
      await links.upsert(link('c1', 'Morning', at: now.subtract(const Duration(days: 4, hours: 3))));

      await service.unlink('p1');

      expect(await links.getForPact('p1'), isNull);
      final e = analytics.loggedEvents.single as PactChecklistUnlinkedEvent;
      expect([e.pactId, e.daysLinked], ['p1', 4]);
    });

    test('no-op without a link: no event', () async {
      await service.unlink('p1');
      expect(analytics.loggedEvents, isEmpty);
    });
  });
}

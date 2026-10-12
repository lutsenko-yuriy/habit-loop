import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/navigation/checklister_selection_handler.dart';
import 'package:habit_loop/slices/checklist/application/checklist_service.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_checklist_run_repository.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../infrastructure/analytics/fake_analytics_service.dart';
import '../infrastructure/checklister/fake_checklister_gateway.dart';

Pact _pact(String id, PactStatus status) => Pact(
      id: id,
      habitName: 'Meditate',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 9, 1),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: status,
    );

void main() {
  late List<String> notices;
  late int changes;
  late ChecklisterSelectionHandler handler;

  setUp(() {
    notices = [];
    changes = 0;
    handler = ChecklisterSelectionHandler(
      service: ChecklistService(
        linkRepository: InMemoryPactChecklistLinkRepository(),
        runRepository: InMemoryChecklistRunRepository(),
        pactRepository: InMemoryPactRepository([_pact('p1', PactStatus.active), _pact('p2', PactStatus.stopped)]),
        showupRepository: InMemoryShowupRepository(),
        gateway: FakeChecklisterGateway(),
        analytics: FakeAnalyticsService(),
      ),
      onNoChecklists: notices.add,
      onChanged: () => changes++,
    );
  });

  SelectionCallback cb(String pactId, ChecklisterCallbackStatus s, {String? id, String? name}) =>
      SelectionCallback(pactId: pactId, status: s, checklistId: id, checklistName: name);

  test('linked: signals a change, no notice', () async {
    await handler(cb('p1', ChecklisterCallbackStatus.selected, id: 'c1', name: 'M'));
    expect([changes, notices], [1, <String>[]]);
  });

  test('unchanged and cancelled still signal a change (section re-reads)', () async {
    await handler(cb('p1', ChecklisterCallbackStatus.cancelled));
    expect(changes, 1);
  });

  test('no checklists: raises the notice for the pact and signals a change', () async {
    await handler(cb('p1', ChecklisterCallbackStatus.error));
    expect([
      changes,
      notices
    ], [
      1,
      ['p1']
    ]);
  });

  test('ignored (stale pact): neither notice nor signal', () async {
    await handler(cb('p2', ChecklisterCallbackStatus.error));
    expect([changes, notices], [0, <String>[]]);
  });
}

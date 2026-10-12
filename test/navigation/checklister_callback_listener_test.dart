import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_links.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/navigation/checklister_callback_listener.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_checklist_run_repository.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_signals.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_signals.dart';

import '../infrastructure/analytics/fake_analytics_service.dart';
import '../infrastructure/checklister/fake_checklister_gateway.dart';
import '../infrastructure/deep_links/fake_incoming_link_service.dart';

Pact _pact(String id, PactStatus status) => Pact(
      id: id,
      habitName: 'Meditate',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 9, 1),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: status,
    );

Uri _cb(String pactId, String query) => Uri.parse('${ChecklisterLinks.selectedCallback(pactId)}&$query');

void main() {
  late InMemoryPactChecklistLinkRepository links;
  late InMemoryChecklistRunRepository runs;
  late FakeIncomingLinkService incoming;
  late ProviderContainer container;

  Future<void> pumpListener(WidgetTester tester) async {
    links = InMemoryPactChecklistLinkRepository();
    runs = InMemoryChecklistRunRepository();
    incoming = FakeIncomingLinkService();
    addTearDown(incoming.dispose);
    container = ProviderContainer(overrides: [
      incomingLinkServiceProvider.overrideWithValue(incoming),
      pactRepositoryProvider.overrideWithValue(
        InMemoryPactRepository([_pact('p1', PactStatus.active), _pact('p2', PactStatus.stopped)]),
      ),
      pactChecklistLinkRepositoryProvider.overrideWithValue(links),
      checklistRunRepositoryProvider.overrideWithValue(runs),
      showupRepositoryProvider.overrideWithValue(InMemoryShowupRepository()),
      checklisterGatewayProvider.overrideWithValue(FakeChecklisterGateway()),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ChecklisterCallbackListener(child: SizedBox()),
      ),
    );
  }

  testWidgets('selected callback links the checklist and bumps the refresh signal', (tester) async {
    await pumpListener(tester);

    incoming.emit(_cb('p1', 'status=selected&checklistId=c1&checklistName=Morning'));
    await tester.pump();
    await tester.pump();

    expect((await links.getForPact('p1'))?.checklistName, 'Morning');
    expect(container.read(checklistSectionRefreshSignalProvider), 1);
  });

  testWidgets('status=error raises the no-checklists notice for that pact', (tester) async {
    await pumpListener(tester);

    incoming.emit(_cb('p1', 'status=error'));
    await tester.pump();
    await tester.pump();

    expect(container.read(checklistNoChecklistsNoticeProvider('p1')), isTrue);
    expect(await links.getForPact('p1'), isNull);
  });

  testWidgets('callback for a stopped pact changes nothing', (tester) async {
    await pumpListener(tester);

    incoming.emit(_cb('p2', 'status=selected&checklistId=c1&checklistName=Morning'));
    await tester.pump();
    await tester.pump();

    expect(await links.getForPact('p2'), isNull);
  });

  testWidgets('run-finished callback for a started run raises the showup notice', (tester) async {
    await pumpListener(tester);
    await runs.upsertStarted(showupId: 's1', pactId: 'p1', checklistId: 'c1', startedAt: DateTime(2026));

    incoming.emit(Uri.parse('${ChecklisterLinks.runFinishedCallback('p1', 's1')}&status=cancelled&checklistId=c1'));
    await tester.pump();
    await tester.pump();

    expect(container.read(checklistRunFinishedNoticeProvider('s1')), ChecklistRunOutcome.failure);
    expect((await runs.getForShowup('s1'))?.outcome, ChecklistRunOutcome.failure);
  });
}

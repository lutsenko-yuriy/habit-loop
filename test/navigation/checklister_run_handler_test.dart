import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/infrastructure/checklister/contracts/checklister_callback.dart';
import 'package:habit_loop/navigation/checklister_run_handler.dart';
import 'package:habit_loop/slices/checklist/application/checklist_service.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_checklist_run_repository.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../infrastructure/analytics/fake_analytics_service.dart';
import '../infrastructure/checklister/fake_checklister_gateway.dart';

void main() {
  late InMemoryChecklistRunRepository runs;
  late List<(String, ChecklistRunOutcome)> finished;
  late ChecklisterRunHandler handler;

  setUp(() {
    runs = InMemoryChecklistRunRepository();
    finished = [];
    handler = ChecklisterRunHandler(
      service: ChecklistService(
        linkRepository: InMemoryPactChecklistLinkRepository(),
        runRepository: runs,
        pactRepository: InMemoryPactRepository(),
        showupRepository: InMemoryShowupRepository(),
        gateway: FakeChecklisterGateway(),
        analytics: FakeAnalyticsService(),
      ),
      onFinished: (id, outcome) => finished.add((id, outcome)),
    );
  });

  RunCallback cb(ChecklisterCallbackStatus s) =>
      RunCallback(pactId: 'p1', showupId: 's1', status: s, checklistId: 'c1', runId: 'r1');

  test('an applied run reports the showup and outcome once', () async {
    await runs.upsertStarted(showupId: 's1', pactId: 'p1', checklistId: 'c1', startedAt: DateTime(2026));
    await handler(cb(ChecklisterCallbackStatus.cancelled));
    await handler(cb(ChecklisterCallbackStatus.cancelled));
    expect(finished, [('s1', ChecklistRunOutcome.failure)]);
  });

  test('a callback without a started run reports nothing', () async {
    await handler(cb(ChecklisterCallbackStatus.completed));
    expect(finished, isEmpty);
  });
}

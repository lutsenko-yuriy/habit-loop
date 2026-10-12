import 'dart:async' show Completer, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_gate.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/checklist_run_repository.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_checklist_run_repository.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/analytics/showup_analytics_events.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/checklister/fake_checklister_gateway.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';

final _now = DateTime(2099, 1, 1, 8, 5);

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2098, 12, 1),
  endDate: DateTime(2099, 6, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _showup = Showup(
  id: 's1',
  pactId: 'p1',
  scheduledAt: DateTime(2099, 1, 1, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

final _link = PactChecklistLink(pactId: 'p1', checklistId: 'c1', checklistName: 'Morning', linkedAt: DateTime(2098));

class _Env {
  _Env(
      {bool flag = true,
      bool linked = true,
      bool installed = true,
      InMemoryPactChecklistLinkRepository? linkRepo,
      ChecklistRunRepository? runRepo})
      : links = linkRepo ?? InMemoryPactChecklistLinkRepository(),
        runs = runRepo ?? InMemoryChecklistRunRepository() {
    gateway.installed = installed;
    if (linked) unawaited(links.upsert(_link));
    rc = FakeRemoteConfigService.withTestDefaults(overrides: {'checklister_integration_enabled': flag});
    final showups = InMemoryShowupRepository([_showup]);
    final pacts = InMemoryPactRepository([_pact]);
    container = ProviderContainer(overrides: [
      pactRepositoryProvider.overrideWithValue(pacts),
      showupRepositoryProvider.overrideWithValue(showups),
      pactTransactionServiceProvider.overrideWithValue(InMemoryPactTransactionService(pacts, showups)),
      syncServiceProvider.overrideWithValue(const NoopSyncService()),
      pactBreakRepositoryProvider.overrideWithValue(InMemoryPactBreakRepository()),
      showupDetailNowProvider.overrideWithValue(_now),
      remoteConfigServiceProvider.overrideWithValue(rc),
      analyticsServiceProvider.overrideWithValue(analytics),
      checklisterGatewayProvider.overrideWithValue(gateway),
      pactChecklistLinkRepositoryProvider.overrideWithValue(links),
      checklistRunRepositoryProvider.overrideWithValue(runs),
    ]);
    // Keep the autoDispose family alive between reads.
    container.listen(showupDetailViewModelProvider('s1'), (_, __) {});
  }

  final InMemoryPactChecklistLinkRepository links;
  final ChecklistRunRepository runs;
  final gateway = FakeChecklisterGateway();
  final analytics = FakeAnalyticsService();
  late final FakeRemoteConfigService rc;
  late final ProviderContainer container;

  ShowupDetailViewModel get vm => container.read(showupDetailViewModelProvider('s1').notifier);
  ShowupDetailState get state => container.read(showupDetailViewModelProvider('s1'));

  Future<void> finishRun(ChecklistRunOutcome outcome) async {
    await runs.upsertStarted(showupId: 's1', pactId: 'p1', checklistId: 'c1', startedAt: _now);
    await runs.markFinished(showupId: 's1', finishedAt: _now, outcome: outcome);
  }
}

/// Link reads block until [release] completes.
class _SlowLinkRepo extends InMemoryPactChecklistLinkRepository {
  final release = Completer<void>();

  @override
  Future<PactChecklistLink?> getForPact(String pactId) async {
    await release.future;
    return super.getForPact(pactId);
  }
}

class _ThrowingRunRepo extends InMemoryChecklistRunRepository {
  @override
  Future<ChecklistRun> upsertStarted({
    required String showupId,
    required String pactId,
    required String checklistId,
    required DateTime startedAt,
  }) =>
      Future.error(StateError('db down'));
}

void main() {
  late _Env env;
  tearDown(() => env.container.dispose());

  group('checklist gate on load', () {
    test('linked pact without a finished run: runRequired', () async {
      env = _Env();
      await env.vm.load();
      expect(env.state.checklistGate, ChecklistGate.runRequired);
    });

    test('no link: none', () async {
      env = _Env(linked: false);
      await env.vm.load();
      expect(env.state.checklistGate, ChecklistGate.none);
    });

    test('flag off: none', () async {
      env = _Env(flag: false);
      await env.vm.load();
      expect(env.state.checklistGate, ChecklistGate.none);
    });

    test('Checklister not installed: none', () async {
      env = _Env(installed: false);
      await env.vm.load();
      expect(env.state.checklistGate, ChecklistGate.none);
    });

    test('finished run: unlocked with its outcome', () async {
      env = _Env();
      await env.finishRun(ChecklistRunOutcome.failure);
      await env.vm.load();
      expect(env.state.checklistGate, ChecklistGate.unlocked);
      expect(env.state.checklistOutcome, ChecklistRunOutcome.failure);
    });

    test('the gate is resolved before loading ends (no Mark as done flash)', () async {
      env = _Env();
      final seen = <ShowupDetailState>[];
      env.container.listen(showupDetailViewModelProvider('s1'), (_, next) => seen.add(next));
      await env.vm.load();
      final loaded = seen.where((s) => !s.isLoading && s.showup != null);
      expect(loaded, isNotEmpty);
      expect(loaded.every((s) => s.checklistGate == ChecklistGate.runRequired), isTrue);
    });

    test('an uninstall during load is not overwritten by the stale load result', () async {
      final slow = _SlowLinkRepo();
      env = _Env(linked: false, linkRepo: slow);
      await slow.upsert(_link);
      final loading = env.vm.load();
      await pumpEventQueue();

      env.gateway.installed = false;
      env.container.invalidate(checklisterInstalledProvider);
      await pumpEventQueue();
      slow.release.complete();
      await loading;
      await pumpEventQueue();

      expect(env.state.checklistGate, ChecklistGate.none);
    });

    test('overlapping loads both complete (the older one yields)', () async {
      env = _Env();
      await Future.wait([env.vm.load(), env.vm.load()]).timeout(const Duration(seconds: 2));
      expect(env.state.isLoading, isFalse);
      expect(env.state.checklistGate, ChecklistGate.runRequired);
    });

    test('install state change re-derives the gate without a reload', () async {
      env = _Env();
      await env.vm.load();
      expect(env.state.checklistGate, ChecklistGate.runRequired);

      env.gateway.installed = false;
      env.container.invalidate(checklisterInstalledProvider);
      await pumpEventQueue();
      expect(env.state.checklistGate, ChecklistGate.none);

      env.gateway.installed = true;
      env.container.invalidate(checklisterInstalledProvider);
      await pumpEventQueue();
      expect(env.state.checklistGate, ChecklistGate.runRequired);
    });
  });

  group('markDone', () {
    test('is a no-op while runRequired', () async {
      env = _Env();
      await env.vm.load();
      await env.vm.markDone();
      expect(env.state.showup!.status, ShowupStatus.pending);
      expect(env.analytics.loggedEvents.whereType<ShowupMarkedDoneEvent>(), isEmpty);
    });

    test('unlocked: marks done with the run outcome', () async {
      env = _Env();
      await env.finishRun(ChecklistRunOutcome.success);
      await env.vm.load();
      await env.vm.markDone();
      await pumpEventQueue();
      expect(env.state.showup!.status, ShowupStatus.done);
      final e = env.analytics.loggedEvents.whereType<ShowupMarkedDoneEvent>().single;
      expect(e.toParameters()['checklist_outcome'], 'success');
    });

    test('no gate: checklist_outcome is none', () async {
      env = _Env(linked: false);
      await env.vm.load();
      await env.vm.markDone();
      await pumpEventQueue();
      final e = env.analytics.loggedEvents.whereType<ShowupMarkedDoneEvent>().single;
      expect(e.toParameters()['checklist_outcome'], 'none');
    });
  });

  group('runChecklist', () {
    test('records the run, opens Checklister and keeps the gate', () async {
      env = _Env();
      await env.vm.load();
      await env.vm.runChecklist();

      expect(env.gateway.launchedUrls.single.host, 'run');
      expect((await env.runs.getForShowup('s1'))?.isFinished, isFalse);
      expect(env.analytics.loggedEvents.whereType<ChecklistRunStartedEvent>(), hasLength(1));
      expect(env.state.checklistGate, ChecklistGate.runRequired);
      expect(env.state.isStartingChecklistRun, isFalse);
      expect(env.state.checklistRunCouldNotOpen, isFalse);
    });

    test('could not open: shows the error and releases the busy flag', () async {
      env = _Env();
      env.gateway.canLaunch = false;
      await env.vm.load();
      await env.vm.runChecklist();

      expect(env.state.checklistRunCouldNotOpen, isTrue);
      expect(env.state.isStartingChecklistRun, isFalse);
    });

    test('a throwing start shows the error and still releases the busy flag', () async {
      env = _Env(runRepo: _ThrowingRunRepo());
      await env.vm.load();
      await env.vm.runChecklist();

      expect(env.state.checklistRunCouldNotOpen, isTrue);
      expect(env.state.isStartingChecklistRun, isFalse);
      expect(env.gateway.launchedUrls, isEmpty);
    });

    test('a second tap while starting is ignored', () async {
      env = _Env();
      await env.vm.load();
      await Future.wait([env.vm.runChecklist(), env.vm.runChecklist()]);
      expect(env.gateway.launchedUrls, hasLength(1));
    });

    test('no-op when the gate is not runRequired', () async {
      env = _Env(linked: false);
      await env.vm.load();
      await env.vm.runChecklist();
      expect(env.gateway.launchedUrls, isEmpty);
    });
  });
}

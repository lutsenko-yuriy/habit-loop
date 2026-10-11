import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';
import 'package:habit_loop/domain/checklist/pact_checklist_link_repository.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/checklist/analytics/checklist_analytics_events.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_signals.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_view_model.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/checklister/fake_checklister_gateway.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

PactChecklistLink _link(String id, String name) =>
    PactChecklistLink(pactId: 'p1', checklistId: id, checklistName: name, linkedAt: DateTime(2026, 5, 1));

/// Link repo whose reads can be held back to simulate a slow query.
class _GatedLinkRepo extends InMemoryPactChecklistLinkRepository implements PactChecklistLinkRepository {
  final gate = Completer<void>();

  @override
  Future<PactChecklistLink?> getForPact(String pactId) async {
    await gate.future;
    return super.getForPact(pactId);
  }
}

void main() {
  late InMemoryPactChecklistLinkRepository links;
  late FakeChecklisterGateway gateway;
  late FakeAnalyticsService analytics;

  ProviderContainer makeContainer([PactChecklistLinkRepository? repo]) {
    final c = ProviderContainer(overrides: [
      pactRepositoryProvider.overrideWithValue(InMemoryPactRepository([_pact])),
      pactChecklistLinkRepositoryProvider.overrideWithValue(repo ?? links),
      checklisterGatewayProvider.overrideWithValue(gateway),
      analyticsServiceProvider.overrideWithValue(analytics),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    links = InMemoryPactChecklistLinkRepository();
    gateway = FakeChecklisterGateway();
    analytics = FakeAnalyticsService();
  });

  test('initial state is not loaded', () {
    final c = makeContainer();
    final state = c.read(pactChecklistSectionViewModelProvider('p1'));
    expect(state.isLoaded, isFalse);
    expect(state.link, isNull);
  });

  test('load: no link -> loaded with null link', () async {
    final c = makeContainer();
    c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    await c.read(pactChecklistSectionViewModelProvider('p1').notifier).load();
    final state = c.read(pactChecklistSectionViewModelProvider('p1'));
    expect(state.isLoaded, isTrue);
    expect(state.link, isNull);
  });

  test('load: existing link is exposed', () async {
    await links.upsert(_link('c1', 'Morning'));
    final c = makeContainer();
    c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    await c.read(pactChecklistSectionViewModelProvider('p1').notifier).load();
    expect(c.read(pactChecklistSectionViewModelProvider('p1')).link?.checklistName, 'Morning');
  });

  test('startSelection launches Checklister and logs selection_started', () async {
    final c = makeContainer();
    c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    final vm = c.read(pactChecklistSectionViewModelProvider('p1').notifier);
    await vm.load();
    await vm.startSelection();

    expect(gateway.launchedUrls, hasLength(1));
    expect(analytics.loggedEvents.single, isA<PactChecklistSelectionStartedEvent>());
    expect(c.read(pactChecklistSectionViewModelProvider('p1')).error, isNull);
  });

  test('startSelection: Checklister cannot be opened -> couldNotOpen error', () async {
    gateway.canLaunch = false;
    final c = makeContainer();
    c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    final vm = c.read(pactChecklistSectionViewModelProvider('p1').notifier);
    await vm.load();
    await vm.startSelection();
    expect(c.read(pactChecklistSectionViewModelProvider('p1')).error, PactChecklistSectionError.couldNotOpen);
  });

  test('remove: clears the link in state and storage, logs unlinked', () async {
    await links.upsert(_link('c1', 'Morning'));
    final c = makeContainer();
    c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    final vm = c.read(pactChecklistSectionViewModelProvider('p1').notifier);
    await vm.load();
    await vm.remove();

    expect(c.read(pactChecklistSectionViewModelProvider('p1')).link, isNull);
    expect(await links.getForPact('p1'), isNull);
    expect(analytics.loggedEvents.single, isA<PactChecklistUnlinkedEvent>());
  });

  test('refresh signal reloads the link (selection callback applied elsewhere)', () async {
    final c = makeContainer();
    c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    await c.read(pactChecklistSectionViewModelProvider('p1').notifier).load();

    await links.upsert(_link('c2', 'Evening'));
    c.read(checklistSectionRefreshSignalProvider.notifier).state++;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(pactChecklistSectionViewModelProvider('p1')).link?.checklistName, 'Evening');
  });

  test('no-checklists notice for this pact sets the noChecklists error; starting a selection clears it', () async {
    final c = makeContainer();
    c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    final vm = c.read(pactChecklistSectionViewModelProvider('p1').notifier);
    await vm.load();

    c.read(checklistNoChecklistsNoticeProvider('p1').notifier).state = true;
    await Future<void>.delayed(Duration.zero);
    expect(c.read(pactChecklistSectionViewModelProvider('p1')).error, PactChecklistSectionError.noChecklists);

    await vm.startSelection();
    expect(c.read(pactChecklistSectionViewModelProvider('p1')).error, isNull);
    expect(c.read(checklistNoChecklistsNoticeProvider('p1')), isFalse);
  });

  test('a notice for another pact is ignored', () async {
    final c = makeContainer();
    c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    await c.read(pactChecklistSectionViewModelProvider('p1').notifier).load();
    c.read(checklistNoChecklistsNoticeProvider('other').notifier).state = true;
    await Future<void>.delayed(Duration.zero);
    expect(c.read(pactChecklistSectionViewModelProvider('p1')).error, isNull);
  });

  test('load finishing after the VM was disposed does not throw', () async {
    final slow = _GatedLinkRepo();
    final c = makeContainer(slow);
    final sub = c.listen(pactChecklistSectionViewModelProvider('p1'), (_, __) {});
    final loading = c.read(pactChecklistSectionViewModelProvider('p1').notifier).load();

    sub.close();
    await Future<void>.delayed(Duration.zero); // autoDispose tears the VM down
    slow.gate.complete();

    await expectLater(loading, completes);
  });
}

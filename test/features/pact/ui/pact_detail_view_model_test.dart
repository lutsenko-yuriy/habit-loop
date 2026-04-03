import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 3, 1),
  endDate: DateTime(2026, 9, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _showups = [
  Showup(id: 's1', pactId: 'p1', scheduledAt: DateTime(2026, 3, 1, 8), duration: const Duration(minutes: 10), status: ShowupStatus.done),
  Showup(id: 's2', pactId: 'p1', scheduledAt: DateTime(2026, 3, 2, 8), duration: const Duration(minutes: 10), status: ShowupStatus.done),
  Showup(id: 's3', pactId: 'p1', scheduledAt: DateTime(2026, 3, 3, 8), duration: const Duration(minutes: 10), status: ShowupStatus.failed),
  Showup(id: 's4', pactId: 'p1', scheduledAt: DateTime(2026, 3, 4, 8), duration: const Duration(minutes: 10), status: ShowupStatus.pending),
];

ProviderContainer _makeContainer({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
}) {
  return ProviderContainer(
    overrides: [
      pactDetailRepositoryProvider.overrideWithValue(InMemoryPactRepository(pacts)),
      pactDetailShowupRepositoryProvider.overrideWithValue(InMemoryShowupRepository(showups)),
    ],
  );
}

void main() {
  group('PactDetailViewModel', () {
    test('initial state is loading with no data', () {
      final container = _makeContainer(pacts: [_pact], showups: _showups);
      addTearDown(container.dispose);
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.isLoading, true);
      expect(state.pact, isNull);
      expect(state.stats, isNull);
    });

    test('load populates pact and stats', () async {
      final container = _makeContainer(pacts: [_pact], showups: _showups);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.isLoading, false);
      expect(state.pact?.habitName, 'Meditate');
      expect(state.stats?.showupsDone, 2);
      expect(state.stats?.showupsFailed, 1);
      expect(state.stats?.showupsRemaining, 1);
      expect(state.stats?.currentStreak, 0); // streak broken by failed
    });

    test('load sets error when pact not found', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('missing').notifier).load();
      final state = container.read(pactDetailViewModelProvider('missing'));
      expect(state.isLoading, false);
      expect(state.loadError, isNotNull);
    });

    test('stopPact updates pact status to stopped with reason', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final container = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider.overrideWithValue(InMemoryShowupRepository(_showups)),
      ]);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact('Not for me');
      final state = container.read(pactDetailViewModelProvider('p1'));
      expect(state.pact?.status, PactStatus.stopped);
      expect(state.pact?.stopReason, 'Not for me');
      // Verify persisted
      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.status, PactStatus.stopped);
    });

    test('stopPact with no reason persists null stopReason', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final container = ProviderContainer(overrides: [
        pactDetailRepositoryProvider.overrideWithValue(pactRepo),
        pactDetailShowupRepositoryProvider.overrideWithValue(InMemoryShowupRepository(_showups)),
      ]);
      addTearDown(container.dispose);
      await container.read(pactDetailViewModelProvider('p1').notifier).load();
      await container.read(pactDetailViewModelProvider('p1').notifier).stopPact(null);
      final persisted = await pactRepo.getPactById('p1');
      expect(persisted?.stopReason, isNull);
    });
  });
}

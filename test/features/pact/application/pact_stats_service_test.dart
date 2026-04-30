import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/features/pact/application/pact_stats_service.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 4, 1),
  endDate: DateTime(2026, 10, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _pendingShowup = Showup(
  id: 's1',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 4, 1, 8),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

void main() {
  group('PactStatsService.persistShowupStatus', () {
    test('updates the showup and refreshes pact stats from one service boundary', () async {
      final pactRepo = InMemoryPactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
      );

      final updatedShowup = await service.persistShowupStatus(
        showup: _pendingShowup,
        status: ShowupStatus.done,
      );

      expect(updatedShowup.status, ShowupStatus.done);

      final persistedShowup = await showupRepo.getShowupById(_pendingShowup.id);
      expect(persistedShowup?.status, ShowupStatus.done);

      final persistedPact = await pactRepo.getPactById(_pact.id);
      final totalShowups = ShowupGenerator.countTotal(persistedPact!);
      expect(persistedPact.stats?.showupsDone, 1);
      expect(persistedPact.stats?.showupsFailed, 0);
      expect(persistedPact.stats?.showupsRemaining, totalShowups - 1);
    });

    test('keeps the showup update when pact stats sync fails', () async {
      final pactRepo = _ThrowingOnUpdatePactRepository([_pact]);
      final showupRepo = InMemoryShowupRepository([_pendingShowup]);
      final service = PactStatsService(
        pactRepository: pactRepo,
        showupRepository: showupRepo,
      );

      final updatedShowup = await service.persistShowupStatus(
        showup: _pendingShowup,
        status: ShowupStatus.failed,
      );

      expect(updatedShowup.status, ShowupStatus.failed);

      final persistedShowup = await showupRepo.getShowupById(_pendingShowup.id);
      expect(persistedShowup?.status, ShowupStatus.failed);
    });
  });
}

class _ThrowingOnUpdatePactRepository extends InMemoryPactRepository {
  _ThrowingOnUpdatePactRepository(super.initialPacts);

  @override
  Future<void> updatePact(Pact pact) async => throw Exception('update failed intentionally');
}

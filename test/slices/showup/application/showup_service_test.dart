import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/application/showup_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

final _pact = Pact(
  id: 'p1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 4, 1),
  endDate: DateTime(2026, 10, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
);

final _showup = Showup(
  id: 's1',
  pactId: 'p1',
  scheduledAt: DateTime(2026, 4, 1, 8),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

ShowupService _makeService({List<Pact> pacts = const [], List<Showup> showups = const []}) => ShowupService(
      pactRepository: InMemoryPactRepository(pacts),
      showupRepository: InMemoryShowupRepository(showups),
    );

void main() {
  group('ShowupService.getShowupById', () {
    test('returns showup when it exists', () async {
      final service = _makeService(showups: [_showup]);
      expect(await service.getShowupById('s1'), _showup);
    });

    test('returns null when not found', () async {
      final service = _makeService();
      expect(await service.getShowupById('missing'), isNull);
    });
  });

  group('ShowupService.getPactById', () {
    test('returns pact when it exists', () async {
      final service = _makeService(pacts: [_pact]);
      expect(await service.getPactById('p1'), _pact);
    });

    test('returns null when not found', () async {
      final service = _makeService();
      expect(await service.getPactById('missing'), isNull);
    });
  });

  group('ShowupService.updateShowup', () {
    test('persists the updated showup', () async {
      final showupRepo = InMemoryShowupRepository([_showup]);
      final service = ShowupService(
        pactRepository: InMemoryPactRepository(),
        showupRepository: showupRepo,
      );
      final updated = _showup.copyWith(status: ShowupStatus.done);
      await service.updateShowup(updated);
      expect(await showupRepo.getShowupById('s1'), updated);
    });
  });
}

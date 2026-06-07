import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/pact/application/pact_list_query_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

Pact _pact(String id, PactStatus status) => Pact(
      id: id,
      habitName: 'Habit $id',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: status,
    );

Showup _showup(String id, String pactId) => Showup(
      id: id,
      pactId: pactId,
      scheduledAt: DateTime(2026, 4, 1, 8),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

PactListQueryService _makeService({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
}) =>
    PactListQueryService(
      pactRepository: InMemoryPactRepository(pacts),
      showupRepository: InMemoryShowupRepository(showups),
    );

void main() {
  group('PactListQueryService.getAllPacts', () {
    test('returns all pacts regardless of status', () async {
      final pacts = [_pact('p1', PactStatus.active), _pact('p2', PactStatus.stopped)];
      expect(await _makeService(pacts: pacts).getAllPacts(), containsAll(pacts));
    });

    test('returns empty when no pacts', () async {
      expect(await _makeService().getAllPacts(), isEmpty);
    });
  });

  group('PactListQueryService.getShowupsForPact', () {
    test('returns showups belonging to the given pact', () async {
      final s1 = _showup('s1', 'p1');
      final s2 = _showup('s2', 'p2');
      final service = _makeService(showups: [s1, s2]);
      expect(await service.getShowupsForPact('p1'), [s1]);
    });

    test('returns empty when pact has no showups', () async {
      expect(await _makeService().getShowupsForPact('p1'), isEmpty);
    });
  });

  group('PactListQueryService.hasActivePacts', () {
    test('returns true when at least one active pact exists', () async {
      final service = _makeService(pacts: [_pact('p1', PactStatus.active)]);
      expect(await service.hasActivePacts(), isTrue);
    });

    test('returns false when no active pacts exist', () async {
      final service = _makeService(pacts: [_pact('p1', PactStatus.stopped)]);
      expect(await service.hasActivePacts(), isFalse);
    });

    test('returns false when no pacts exist', () async {
      expect(await _makeService().hasActivePacts(), isFalse);
    });
  });
}

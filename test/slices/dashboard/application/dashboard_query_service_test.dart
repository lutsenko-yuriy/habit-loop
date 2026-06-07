import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/dashboard/application/dashboard_query_service.dart';
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

Showup _showup(String id, String pactId, DateTime scheduledAt) => Showup(
      id: id,
      pactId: pactId,
      scheduledAt: scheduledAt,
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

DashboardQueryService _makeService({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
}) =>
    DashboardQueryService(
      pactRepository: InMemoryPactRepository(pacts),
      showupRepository: InMemoryShowupRepository(showups),
    );

void main() {
  group('DashboardQueryService.getAllPacts', () {
    test('returns all pacts', () async {
      final active = _pact('p1', PactStatus.active);
      final stopped = _pact('p2', PactStatus.stopped);
      final service = _makeService(pacts: [active, stopped]);
      final result = await service.getAllPacts();
      expect(result, containsAll([active, stopped]));
    });

    test('returns empty when no pacts', () async {
      expect(await _makeService().getAllPacts(), isEmpty);
    });
  });

  group('DashboardQueryService.getActivePacts', () {
    test('returns only active pacts', () async {
      final active = _pact('p1', PactStatus.active);
      final stopped = _pact('p2', PactStatus.stopped);
      final service = _makeService(pacts: [active, stopped]);
      expect(await service.getActivePacts(), [active]);
    });
  });

  group('DashboardQueryService.getLatestScheduledAtForPact', () {
    test('returns latest scheduledAt for the pact', () async {
      final earlier = _showup('s1', 'p1', DateTime(2026, 4, 1, 8));
      final later = _showup('s2', 'p1', DateTime(2026, 4, 3, 8));
      final service = _makeService(showups: [earlier, later]);
      expect(await service.getLatestScheduledAtForPact('p1'), DateTime(2026, 4, 3, 8));
    });

    test('returns null when pact has no showups', () async {
      expect(await _makeService().getLatestScheduledAtForPact('p1'), isNull);
    });
  });

  group('DashboardQueryService.getShowupsForDateRange', () {
    test('returns showups within the range', () async {
      final inside = _showup('s1', 'p1', DateTime(2026, 4, 5, 8));
      final outside = _showup('s2', 'p1', DateTime(2026, 4, 15, 8));
      final service = _makeService(showups: [inside, outside]);
      final result = await service.getShowupsForDateRange(
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 10),
      );
      expect(result, [inside]);
    });
  });
}

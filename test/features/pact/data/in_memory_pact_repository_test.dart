import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';

void main() {
  late InMemoryPactRepository repo;

  final activePact = Pact(
    id: '1',
    habitName: 'Meditate',
    startDate: DateTime(2026, 3, 1),
    endDate: DateTime(2026, 9, 1),
    showupDuration: const Duration(minutes: 10),
    schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
    status: PactStatus.active,
  );

  final stoppedPact = Pact(
    id: '2',
    habitName: 'Jog',
    startDate: DateTime(2026, 3, 1),
    endDate: DateTime(2026, 9, 1),
    showupDuration: const Duration(minutes: 30),
    schedule: const DailySchedule(timeOfDay: Duration(hours: 6)),
    status: PactStatus.stopped,
    stopReason: 'Knee injury',
  );

  group('InMemoryPactRepository', () {
    test('getActivePacts returns only active pacts', () async {
      repo = InMemoryPactRepository([activePact, stoppedPact]);

      final result = await repo.getActivePacts();

      expect(result, [activePact]);
    });

    test('getActivePacts returns empty list when no pacts', () async {
      repo = InMemoryPactRepository();

      final result = await repo.getActivePacts();

      expect(result, isEmpty);
    });

    test('getPactById returns pact when found', () async {
      repo = InMemoryPactRepository([activePact, stoppedPact]);

      final result = await repo.getPactById('1');

      expect(result, activePact);
    });

    test('getPactById returns null when not found', () async {
      repo = InMemoryPactRepository([activePact]);

      final result = await repo.getPactById('999');

      expect(result, isNull);
    });

    test('savePact adds a new pact to the repository', () async {
      repo = InMemoryPactRepository();

      await repo.savePact(activePact);

      final result = await repo.getPactById('1');
      expect(result, activePact);
    });

    test('savePact makes pact available in getActivePacts', () async {
      repo = InMemoryPactRepository();

      await repo.savePact(activePact);

      final result = await repo.getActivePacts();
      expect(result, [activePact]);
    });

    test('getAllPacts returns all pacts regardless of status', () async {
      repo = InMemoryPactRepository([activePact, stoppedPact]);

      final result = await repo.getAllPacts();

      expect(result, [activePact, stoppedPact]);
    });

    test('updatePact replaces existing pact by id', () async {
      repo = InMemoryPactRepository([activePact]);
      final stopped = activePact.copyWith(
        status: PactStatus.stopped,
        stopReason: 'Lost interest',
      );

      await repo.updatePact(stopped);

      final result = await repo.getPactById('1');
      expect(result?.status, PactStatus.stopped);
      expect(result?.stopReason, 'Lost interest');
    });

    test('updatePact throws if id not found', () async {
      repo = InMemoryPactRepository([activePact]);
      final unknown = Pact(
        id: 'unknown',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 9, 1),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.stopped,
      );

      expect(() => repo.updatePact(unknown), throwsArgumentError);
    });

    test('savePact throws if a pact with the same id already exists', () async {
      repo = InMemoryPactRepository([activePact]);

      expect(() => repo.savePact(activePact), throwsArgumentError);
    });
  });
}

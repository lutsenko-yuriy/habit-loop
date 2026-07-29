import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';

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

    test('archivePact throws if pact id not found', () async {
      repo = InMemoryPactRepository([activePact]);

      expect(() => repo.archivePact('non-existent', true), throwsArgumentError);
    });

    group('getSuccessor', () {
      test('returns the pact whose predecessorPactId matches', () async {
        final successor = Pact(
          id: 'succ',
          habitName: 'Meditate (v2)',
          startDate: activePact.startDate,
          endDate: activePact.endDate,
          showupDuration: activePact.showupDuration,
          schedule: activePact.schedule,
          status: PactStatus.active,
          predecessorPactId: activePact.id,
        );
        repo = InMemoryPactRepository([activePact, successor]);

        final result = await repo.getSuccessor(activePact.id);

        expect(result, successor);
      });

      test('returns null when no pact has this predecessorPactId', () async {
        repo = InMemoryPactRepository([activePact]);

        final result = await repo.getSuccessor(activePact.id);

        expect(result, isNull);
      });
    });

    group('savePact — successor uniqueness', () {
      test('throws ArgumentError when predecessorPactId already has a successor', () async {
        final firstSuccessor = Pact(
          id: 'succ-1',
          habitName: 'Meditate (v2)',
          startDate: activePact.startDate,
          endDate: activePact.endDate,
          showupDuration: activePact.showupDuration,
          schedule: activePact.schedule,
          status: PactStatus.active,
          predecessorPactId: activePact.id,
        );
        final secondSuccessor = Pact(
          id: 'succ-2',
          habitName: 'Meditate (v3)',
          startDate: activePact.startDate,
          endDate: activePact.endDate,
          showupDuration: activePact.showupDuration,
          schedule: activePact.schedule,
          status: PactStatus.active,
          predecessorPactId: activePact.id,
        );
        repo = InMemoryPactRepository([activePact]);
        await repo.savePact(firstSuccessor);

        expect(() => repo.savePact(secondSuccessor), throwsArgumentError);
      });

      test('allows saving a pact with a null predecessorPactId regardless of existing successors', () async {
        repo = InMemoryPactRepository([activePact]);
        final unrelated = Pact(
          id: 'unrelated',
          habitName: 'Jog',
          startDate: activePact.startDate,
          endDate: activePact.endDate,
          showupDuration: activePact.showupDuration,
          schedule: activePact.schedule,
          status: PactStatus.active,
        );

        await repo.savePact(unrelated);

        expect(await repo.getPactById('unrelated'), unrelated);
      });
    });
  });
}

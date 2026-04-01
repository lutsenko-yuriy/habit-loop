import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_generator.dart';

void main() {
  group('ShowupGenerator + ShowupRepository integration', () {
    test('generated showup ids are unique within a single pact', () {
      final pact = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

      final showups = ShowupGenerator.generate(pact);
      final ids = showups.map((s) => s.id).toSet();

      expect(ids.length, showups.length,
          reason: 'Every generated showup must have a unique id');
    });

    test('generated showup ids are unique across two pacts with the same schedule', () {
      final pact1 = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );
      final pact2 = Pact(
        id: 'pact-2',
        habitName: 'Jog',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        showupDuration: const Duration(minutes: 30),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

      final all = [
        ...ShowupGenerator.generate(pact1),
        ...ShowupGenerator.generate(pact2),
      ];
      final ids = all.map((s) => s.id).toSet();

      expect(ids.length, all.length,
          reason: 'Showup ids must be unique across different pacts');
    });

    test('all generated showups can be saved and retrieved without collision', () async {
      final repo = InMemoryShowupRepository();
      final pact = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
        status: PactStatus.active,
      );

      final showups = ShowupGenerator.generate(pact);
      await repo.saveShowups(showups);

      final saved = await repo.getShowupsForPact('pact-1');
      expect(saved.length, showups.length);

      final savedIds = saved.map((s) => s.id).toSet();
      expect(savedIds.length, showups.length,
          reason: 'No showup ids should collide after persistence');
    });
  });
}

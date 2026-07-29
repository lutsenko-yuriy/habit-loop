import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/schedule_type.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/application/pact_chain_service.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';

Pact _pact({
  required String id,
  required String habitName,
  String? predecessorPactId,
  Duration showupDuration = const Duration(minutes: 10),
  ShowupSchedule schedule = const DailySchedule(timeOfDay: Duration(hours: 8)),
  Duration? reminderOffset,
  PactStatus status = PactStatus.stopped,
}) =>
    Pact(
      id: id,
      habitName: habitName,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 7, 1),
      showupDuration: showupDuration,
      schedule: schedule,
      status: status,
      reminderOffset: reminderOffset,
      predecessorPactId: predecessorPactId,
    );

void main() {
  late InMemoryPactRepository repo;
  late PactChainService service;

  setUp(() {
    repo = InMemoryPactRepository();
    service = PactChainService(pactRepository: repo);
  });

  group('defaultNameFor', () {
    test('predecessor is the root: default name is "<name> (v2)"', () async {
      final root = _pact(id: 'root', habitName: 'Vibe coding');
      repo = InMemoryPactRepository([root]);
      service = PactChainService(pactRepository: repo);

      final result = await service.defaultNameFor(root);

      expect(result, 'Vibe coding (v2)');
    });

    test('predecessor is one hop from the root: default name is "<root name> (v3)"', () async {
      final root = _pact(id: 'root', habitName: 'Vibe coding');
      final v2 = _pact(id: 'v2', habitName: 'Vibe coding (v2)', predecessorPactId: 'root');
      repo = InMemoryPactRepository([root, v2]);
      service = PactChainService(pactRepository: repo);

      final result = await service.defaultNameFor(v2);

      expect(result, 'Vibe coding (v3)');
    });

    test('uses the root\'s current habit name, ignoring intermediate renames', () async {
      final root = _pact(id: 'root', habitName: 'Vibe coding (renamed)');
      final v2 = _pact(id: 'v2', habitName: 'Something else entirely', predecessorPactId: 'root');
      repo = InMemoryPactRepository([root, v2]);
      service = PactChainService(pactRepository: repo);

      final result = await service.defaultNameFor(v2);

      expect(result, 'Vibe coding (renamed) (v3)');
    });

    test('tolerates a dangling predecessor reference by treating the current pact as root', () async {
      final orphan = _pact(id: 'orphan', habitName: 'Orphaned', predecessorPactId: 'missing');
      repo = InMemoryPactRepository([orphan]);
      service = PactChainService(pactRepository: repo);

      final result = await service.defaultNameFor(orphan);

      expect(result, 'Orphaned (v2)');
    });
  });

  group('buildPrefillFor', () {
    test('carries schedule, showup duration and reminder offset from the predecessor', () async {
      final predecessor = _pact(
        id: 'root',
        habitName: 'Vibe coding',
        showupDuration: const Duration(minutes: 25),
        schedule: const WeekdaySchedule(entries: [WeekdayEntry(weekday: 2, timeOfDay: Duration(hours: 9))]),
        reminderOffset: const Duration(minutes: 15),
      );
      repo = InMemoryPactRepository([predecessor]);
      service = PactChainService(pactRepository: repo);
      final today = DateTime(2026, 8, 1);

      final builder = await service.buildPrefillFor(predecessor, today: today);

      expect(builder.showupDuration, const Duration(minutes: 25));
      expect(builder.reminderOffset, const Duration(minutes: 15));
      expect(builder.scheduleType, ScheduleType.slot);
      expect(
        builder.schedule,
        SlotSchedule(slots: [
          WeeklySlot(weekdays: {2}, timeOfDay: const Duration(hours: 9))
        ]),
      );
    });

    test('sets the default versioned habit name', () async {
      final predecessor = _pact(id: 'root', habitName: 'Vibe coding');
      repo = InMemoryPactRepository([predecessor]);
      service = PactChainService(pactRepository: repo);

      final builder = await service.buildPrefillFor(predecessor, today: DateTime(2026, 8, 1));

      expect(builder.habitName, 'Vibe coding (v2)');
    });

    test('resets the start date to today rather than carrying the predecessor\'s', () async {
      final predecessor = _pact(id: 'root', habitName: 'Vibe coding');
      repo = InMemoryPactRepository([predecessor]);
      service = PactChainService(pactRepository: repo);
      final today = DateTime(2026, 8, 15);

      final builder = await service.buildPrefillFor(predecessor, today: today);

      expect(builder.startDate, DateTime(2026, 8, 15));
    });

    test('defaults the end date like a fresh pact rather than carrying the predecessor\'s', () async {
      final predecessor = _pact(id: 'root', habitName: 'Vibe coding');
      repo = InMemoryPactRepository([predecessor]);
      service = PactChainService(pactRepository: repo);
      final today = DateTime(2026, 8, 15);

      final builder = await service.buildPrefillFor(predecessor, today: today);

      expect(builder.endDate, DateTime(2027, 2, 15));
    });

    test('carries a null reminder offset as null', () async {
      final predecessor = _pact(id: 'root', habitName: 'Vibe coding');
      repo = InMemoryPactRepository([predecessor]);
      service = PactChainService(pactRepository: repo);

      final builder = await service.buildPrefillFor(predecessor, today: DateTime(2026, 8, 1));

      expect(builder.reminderOffset, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_generation_service.dart';

void main() {
  // A helper to build a simple daily-schedule pact spanning a fixed range.
  Pact makePact({
    required String id,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return Pact(
      id: id,
      habitName: 'Test habit',
      startDate: startDate,
      endDate: endDate,
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.active,
    );
  }

  late InMemoryShowupRepository repo;
  late ShowupGenerationService service;

  setUp(() {
    repo = InMemoryShowupRepository();
    service = ShowupGenerationService(repository: repo);
  });

  group('ShowupGenerationService.ensureShowupsExist', () {
    test('generates showups for the requested window when none exist', () async {
      final pact = makePact(
        id: 'pact-1',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );
      final from = DateTime(2026, 4, 1);
      final to = DateTime(2026, 4, 7);

      await service.ensureShowupsExist(pact, from: from, to: to);

      final stored = await repo.getShowupsForPact('pact-1');
      // Daily from Apr 1 to Apr 7 inclusive = 7 showups.
      expect(stored.length, 7);
      expect(stored.map((s) => s.scheduledAt.day).toList(), equals([1, 2, 3, 4, 5, 6, 7]));
    });

    test('is idempotent — calling twice does not duplicate showups', () async {
      final pact = makePact(
        id: 'pact-1',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );
      final from = DateTime(2026, 4, 1);
      final to = DateTime(2026, 4, 7);

      await service.ensureShowupsExist(pact, from: from, to: to);
      await service.ensureShowupsExist(pact, from: from, to: to);

      final stored = await repo.getShowupsForPact('pact-1');
      expect(stored.length, 7, reason: 'Second call must not create duplicates');
    });

    test('calling with overlapping windows deduplicates correctly', () async {
      final pact = makePact(
        id: 'pact-1',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );

      // First call: Apr 1–5 (5 showups).
      await service.ensureShowupsExist(
        pact,
        from: DateTime(2026, 4, 1),
        to: DateTime(2026, 4, 5),
      );
      // Second call: Apr 3–9 (overlaps on Apr 3–5).
      await service.ensureShowupsExist(
        pact,
        from: DateTime(2026, 4, 3),
        to: DateTime(2026, 4, 9),
      );

      final stored = await repo.getShowupsForPact('pact-1');
      // Apr 1–9 = 9 unique showups.
      expect(stored.length, 9, reason: 'Overlapping calls must not duplicate showups in the overlap');
    });

    test('handles two separate pacts independently', () async {
      final pact1 = makePact(
        id: 'pact-1',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );
      final pact2 = makePact(
        id: 'pact-2',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );
      final from = DateTime(2026, 4, 1);
      final to = DateTime(2026, 4, 3);

      await service.ensureShowupsExist(pact1, from: from, to: to);
      await service.ensureShowupsExist(pact2, from: from, to: to);

      final stored1 = await repo.getShowupsForPact('pact-1');
      final stored2 = await repo.getShowupsForPact('pact-2');
      expect(stored1.length, 3, reason: 'pact-1 must have 3 showups');
      expect(stored2.length, 3, reason: 'pact-2 must have 3 showups');
      // IDs from different pacts must not collide.
      final allIds = {
        ...stored1.map((s) => s.id),
        ...stored2.map((s) => s.id),
      };
      expect(allIds.length, 6, reason: 'All IDs must be unique across pacts');
    });

    test('does not generate showups outside pact boundaries', () async {
      final pact = makePact(
        id: 'pact-1',
        startDate: DateTime(2026, 4, 5),
        endDate: DateTime(2026, 4, 10),
      );
      // Request window extends beyond pact boundaries on both ends.
      await service.ensureShowupsExist(
        pact,
        from: DateTime(2026, 4, 1),
        to: DateTime(2026, 4, 20),
      );

      final stored = await repo.getShowupsForPact('pact-1');
      // Only Apr 5–10 inclusive = 6 showups.
      expect(stored.length, 6);
      expect(stored.first.scheduledAt.day, 5);
      expect(stored.last.scheduledAt.day, 10);
    });

    test('generates nothing when window is entirely outside pact range', () async {
      final pact = makePact(
        id: 'pact-1',
        startDate: DateTime(2026, 4, 15),
        endDate: DateTime(2026, 4, 30),
      );
      // Window is entirely before the pact starts.
      await service.ensureShowupsExist(
        pact,
        from: DateTime(2026, 4, 1),
        to: DateTime(2026, 4, 10),
      );

      final stored = await repo.getShowupsForPact('pact-1');
      expect(stored, isEmpty);
    });

    test(
        'skips showups scheduled before pact.createdAt — '
        'dashboard re-generation must not resurrect past-due slots '
        'that were intentionally omitted at creation time', () async {
      // Simulate: pact starting today (April 1) with a daily 8am schedule,
      // but created at 22:00 that evening. The 8am slot is 14 hours in the past.
      final pact = Pact(
        id: 'pact-1',
        habitName: 'Test habit',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
        showupDuration: const Duration(minutes: 10),
        schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
        status: PactStatus.active,
        createdAt: DateTime(2026, 4, 1, 22, 0), // created at 22:00
      );

      // Dashboard lazy-loads the window starting from today midnight.
      await service.ensureShowupsExist(
        pact,
        from: DateTime(2026, 4, 1),
        to: DateTime(2026, 4, 7),
      );

      final stored = await repo.getShowupsForPact('pact-1');

      // April 1 08:00 is before createdAt (22:00) — must be excluded.
      expect(
        stored.any((s) => s.scheduledAt == DateTime(2026, 4, 1, 8, 0)),
        isFalse,
        reason: 'Showup at 08:00 is before createdAt (22:00) and must be skipped',
      );
      // April 2 onwards must be included (their 8am is after createdAt).
      expect(
        stored.any((s) => s.scheduledAt == DateTime(2026, 4, 2, 8, 0)),
        isTrue,
        reason: 'Showup at Apr 2 08:00 is after createdAt and must be saved',
      );
      // Total: Apr 2–7 = 6 showups (Apr 1 skipped).
      expect(stored.length, 6);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';

void main() {
  late InMemoryPactBreakRepository repo;

  PactBreak makeBreak({
    String id = 'break-1',
    String pactId = 'pact-1',
    DateTime? startDate,
    DateTime? plannedEndDate,
    DateTime? stoppedAt,
    String rationale = 'Recovering from a cold',
  }) =>
      PactBreak(
        id: id,
        pactId: pactId,
        startDate: startDate ?? DateTime(2026, 3, 1),
        rationale: rationale,
        plannedEndDate: plannedEndDate,
        stoppedAt: stoppedAt,
      );

  group('InMemoryPactBreakRepository', () {
    setUp(() {
      repo = InMemoryPactBreakRepository();
    });

    group('saveBreak', () {
      test('persists a break that can be retrieved via getBreaksForPact', () async {
        await repo.saveBreak(makeBreak());

        final breaks = await repo.getBreaksForPact('pact-1');
        expect(breaks, hasLength(1));
        expect(breaks.first.id, equals('break-1'));
      });

      test('throws ArgumentError if a break with the same id already exists', () async {
        await repo.saveBreak(makeBreak());
        expect(() => repo.saveBreak(makeBreak()), throwsArgumentError);
      });
    });

    group('updateBreak', () {
      test('persists changes to an existing break', () async {
        await repo.saveBreak(makeBreak());

        final stoppedAt = DateTime(2026, 3, 5);
        await repo.updateBreak(makeBreak(stoppedAt: stoppedAt));

        final breaks = await repo.getBreaksForPact('pact-1');
        expect(breaks.first.stoppedAt, equals(stoppedAt));
      });

      test('throws ArgumentError if no break with the given id exists', () async {
        expect(() => repo.updateBreak(makeBreak()), throwsArgumentError);
      });
    });

    group('getBreaksForPact', () {
      test('returns an empty list when no breaks exist for the pact', () async {
        expect(await repo.getBreaksForPact('pact-1'), isEmpty);
      });

      test('only returns breaks belonging to the given pact', () async {
        await repo.saveBreak(makeBreak(id: 'break-1', pactId: 'pact-1'));
        await repo.saveBreak(makeBreak(id: 'break-2', pactId: 'pact-2'));

        final breaks = await repo.getBreaksForPact('pact-1');
        expect(breaks, hasLength(1));
        expect(breaks.first.id, equals('break-1'));
      });

      test('returns breaks oldest-start-date first', () async {
        await repo.saveBreak(makeBreak(id: 'break-later', startDate: DateTime(2026, 3, 10)));
        await repo.saveBreak(makeBreak(id: 'break-earlier', startDate: DateTime(2026, 3, 1)));

        final breaks = await repo.getBreaksForPact('pact-1');
        expect(breaks.map((b) => b.id).toList(), equals(['break-earlier', 'break-later']));
      });
    });

    group('deleteBreaksForPact', () {
      test('removes all breaks for the given pact', () async {
        await repo.saveBreak(makeBreak(id: 'break-1'));
        await repo.saveBreak(makeBreak(id: 'break-2', startDate: DateTime(2026, 4, 1)));

        await repo.deleteBreaksForPact('pact-1');

        expect(await repo.getBreaksForPact('pact-1'), isEmpty);
      });

      test('no-op when no breaks for pact', () async {
        await expectLater(() => repo.deleteBreaksForPact('pact-1'), returnsNormally);
      });

      test('only deletes breaks for the targeted pact', () async {
        await repo.saveBreak(makeBreak(id: 'break-1', pactId: 'pact-1'));
        await repo.saveBreak(makeBreak(id: 'break-2', pactId: 'pact-2'));

        await repo.deleteBreaksForPact('pact-1');

        expect(await repo.getBreaksForPact('pact-2'), hasLength(1));
      });
    });

    test('constructor accepts an initial list of breaks', () async {
      repo = InMemoryPactBreakRepository([makeBreak()]);
      final breaks = await repo.getBreaksForPact('pact-1');
      expect(breaks, hasLength(1));
    });

    group('getBreakById', () {
      test('returns the break with the given id', () async {
        await repo.saveBreak(makeBreak());
        final result = await repo.getBreakById('break-1');
        expect(result?.id, equals('break-1'));
      });

      test('returns null when no break with the given id exists', () async {
        expect(await repo.getBreakById('nonexistent'), isNull);
      });
    });
  });
}

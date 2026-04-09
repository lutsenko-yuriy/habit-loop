import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

void main() {
  late InMemoryShowupRepository repo;

  final showupMar28 = Showup(
    id: '1',
    pactId: 'pact-1',
    scheduledAt: DateTime(2026, 3, 28, 7, 0),
    duration: const Duration(minutes: 10),
    status: ShowupStatus.done,
  );

  final showupMar29Morning = Showup(
    id: '2',
    pactId: 'pact-1',
    scheduledAt: DateTime(2026, 3, 29, 7, 0),
    duration: const Duration(minutes: 10),
    status: ShowupStatus.pending,
  );

  final showupMar29Evening = Showup(
    id: '3',
    pactId: 'pact-2',
    scheduledAt: DateTime(2026, 3, 29, 18, 0),
    duration: const Duration(minutes: 30),
    status: ShowupStatus.pending,
  );

  final showupMar30 = Showup(
    id: '4',
    pactId: 'pact-1',
    scheduledAt: DateTime(2026, 3, 30, 7, 0),
    duration: const Duration(minutes: 10),
    status: ShowupStatus.pending,
  );

  group('InMemoryShowupRepository', () {
    setUp(() {
      repo = InMemoryShowupRepository([
        showupMar28,
        showupMar29Morning,
        showupMar29Evening,
        showupMar30,
      ]);
    });

    test('getShowupsForDate returns showups matching the date', () async {
      final result = await repo.getShowupsForDate(DateTime(2026, 3, 29));

      expect(result, [showupMar29Morning, showupMar29Evening]);
    });

    test('getShowupsForDate returns empty list for date with no showups',
        () async {
      final result = await repo.getShowupsForDate(DateTime(2026, 4, 1));

      expect(result, isEmpty);
    });

    test('getShowupsForDateRange returns showups within range', () async {
      final result = await repo.getShowupsForDateRange(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 29),
      );

      expect(result, [showupMar28, showupMar29Morning, showupMar29Evening]);
    });

    test('getShowupsForDateRange returns empty for empty repo', () async {
      repo = InMemoryShowupRepository();

      final result = await repo.getShowupsForDateRange(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 30),
      );

      expect(result, isEmpty);
    });

    test('saveShowup adds a new showup', () async {
      repo = InMemoryShowupRepository();
      await repo.saveShowup(showupMar28);

      final result = await repo.getShowupsForDate(DateTime(2026, 3, 28));
      expect(result, [showupMar28]);
    });

    test('saveShowup throws if id already exists', () async {
      expect(() => repo.saveShowup(showupMar28), throwsArgumentError);
    });

    test('saveShowups adds multiple showups', () async {
      repo = InMemoryShowupRepository();
      final result = await repo.saveShowups([showupMar28, showupMar29Morning]);

      expect(result.savedCount, 2);
      expect(result.skippedIds, isEmpty);
      expect(result.allSaved, isTrue);

      final stored = await repo.getShowupsForDateRange(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 29),
      );
      expect(stored, [showupMar28, showupMar29Morning]);
    });

    test('saveShowups skips duplicates and reports them', () async {
      // showupMar28 (id='1') already exists in setUp
      final newShowup = Showup(
        id: '99',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 4, 1, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );
      final result = await repo.saveShowups([showupMar28, newShowup]);

      expect(result.savedCount, 1);
      expect(result.skippedIds, ['1']);
      expect(result.allSaved, isFalse);
    });

    test('saveShowups deduplicates within the input list', () async {
      repo = InMemoryShowupRepository();
      final result = await repo.saveShowups([showupMar28, showupMar28]);

      expect(result.savedCount, 1);
      expect(result.skippedIds, ['1']);

      final stored = await repo.getShowupsForPact('pact-1');
      expect(stored.length, 1);
    });

    test('updateShowup replaces existing showup by id', () async {
      final updated = showupMar28.copyWith(status: ShowupStatus.done, note: 'Did it!');
      await repo.updateShowup(updated);

      final result = await repo.getShowupsForDate(DateTime(2026, 3, 28));
      expect(result.first.status, ShowupStatus.done);
      expect(result.first.note, 'Did it!');
    });

    test('updateShowup throws if id not found', () async {
      final unknown = Showup(
        id: 'unknown',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 28, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
      );

      expect(() => repo.updateShowup(unknown), throwsArgumentError);
    });

    test('getShowupById returns the correct showup', () async {
      final result = await repo.getShowupById('2');
      expect(result, showupMar29Morning);
    });

    test('getShowupById returns null for unknown id', () async {
      final result = await repo.getShowupById('unknown');
      expect(result, isNull);
    });

    test('getShowupsForPact returns showups for given pactId', () async {
      final result = await repo.getShowupsForPact('pact-1');
      expect(result, [showupMar28, showupMar29Morning, showupMar30]);
    });

    test('getShowupsForPact returns empty for unknown pactId', () async {
      final result = await repo.getShowupsForPact('unknown');
      expect(result, isEmpty);
    });

    test('countShowupsForPact returns count of showups for given pactId',
        () async {
      // pact-1 has showupMar28, showupMar29Morning, showupMar30 = 3 showups.
      final result = await repo.countShowupsForPact('pact-1');
      expect(result, 3);
    });

    test('countShowupsForPact returns 0 for unknown pactId', () async {
      final result = await repo.countShowupsForPact('unknown');
      expect(result, 0);
    });

    test('countShowupsForPact returns only count for specified pactId',
        () async {
      // pact-2 has only showupMar29Evening = 1 showup.
      final result = await repo.countShowupsForPact('pact-2');
      expect(result, 1);
    });

    test('countShowupsForPact returns 0 for empty repository', () async {
      repo = InMemoryShowupRepository();
      final result = await repo.countShowupsForPact('pact-1');
      expect(result, 0);
    });
  });
}

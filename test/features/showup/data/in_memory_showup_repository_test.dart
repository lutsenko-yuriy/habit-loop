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
  });
}

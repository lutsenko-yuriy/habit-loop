import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

Pact _pact(String id, PactStatus status, {DateTime? endDate, bool archived = false}) => Pact(
      id: id,
      habitName: 'Habit $id',
      startDate: DateTime(2026, 1, 1),
      endDate: endDate ?? DateTime(2026, 10, 1),
      showupDuration: const Duration(minutes: 15),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: status,
      archived: archived,
    );

Showup _showup(String id, String pactId, DateTime scheduledAt, {ShowupStatus status = ShowupStatus.pending}) => Showup(
      id: id,
      pactId: pactId,
      scheduledAt: scheduledAt,
      duration: const Duration(minutes: 15),
      status: status,
    );

ProviderContainer _makeContainer({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
}) {
  return ProviderContainer(overrides: [
    pactRepositoryProvider.overrideWithValue(InMemoryPactRepository(pacts)),
    showupRepositoryProvider.overrideWithValue(InMemoryShowupRepository(showups)),
  ]);
}

void main() {
  group('PactListViewModel', () {
    test('initial state: empty entries, all filters on, not loading', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final state = c.read(pactListViewModelProvider);
      expect(state.entries, isEmpty);
      expect(state.isLoading, false);
      expect(state.activeFilters, {PactStatus.active, PactStatus.completed, PactStatus.stopped});
    });

    test('load with no pacts → empty entries', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      expect(c.read(pactListViewModelProvider).entries, isEmpty);
    });

    test('load with active pact sets nextShowupAt to earliest pending showup', () async {
      final pact = _pact('p1', PactStatus.active);
      // Both dates are far in the future so they are never filtered out by the
      // "past showups are ignored" logic regardless of when the test runs.
      final future = DateTime(2099, 12, 10, 9);
      final earlier = DateTime(2099, 12, 5, 9);
      final c = _makeContainer(
        pacts: [pact],
        showups: [
          _showup('s1', 'p1', future),
          _showup('s2', 'p1', earlier),
        ],
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.nextShowupAt, earlier);
    });

    test('load: past pending showups are ignored for nextShowupAt', () async {
      final pact = _pact('p1', PactStatus.active);
      final past = DateTime(2026, 1, 5, 9); // in the past relative to test
      final future = DateTime(2026, 12, 5, 9);
      final c = _makeContainer(
        pacts: [pact],
        showups: [
          _showup('s1', 'p1', past),
          _showup('s2', 'p1', future),
        ],
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.nextShowupAt, future);
    });

    test('load with stopped pact: nextShowupAt is null', () async {
      final pact = _pact('p1', PactStatus.stopped);
      final c = _makeContainer(
        pacts: [pact],
        showups: [_showup('s1', 'p1', DateTime(2026, 12, 5, 9))],
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.nextShowupAt, isNull);
    });

    test('load with completed pact: nextShowupAt is null', () async {
      final pact = _pact('p1', PactStatus.completed);
      final c = _makeContainer(pacts: [pact]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.nextShowupAt, isNull);
    });

    test('entries sorted: active → completed → stopped', () async {
      final c = _makeContainer(pacts: [
        _pact('stopped', PactStatus.stopped),
        _pact('completed', PactStatus.completed),
        _pact('active', PactStatus.active),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final ids = c.read(pactListViewModelProvider).entries.map((e) => e.pact.id).toList();
      expect(ids, ['active', 'completed', 'stopped']);
    });

    test('active pacts sorted by nextShowupAt ascending within group', () async {
      final p1 = _pact('p1', PactStatus.active);
      final p2 = _pact('p2', PactStatus.active);
      final c = _makeContainer(
        pacts: [p1, p2],
        showups: [
          _showup('s1', 'p1', DateTime(2026, 12, 10)),
          _showup('s2', 'p2', DateTime(2026, 12, 5)),
        ],
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final ids = c.read(pactListViewModelProvider).entries.map((e) => e.pact.id).toList();
      expect(ids, ['p2', 'p1']);
    });

    test('counts computed correctly', () async {
      final c = _makeContainer(pacts: [
        _pact('a1', PactStatus.active),
        _pact('a2', PactStatus.active),
        _pact('d1', PactStatus.completed),
        _pact('c1', PactStatus.stopped),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final state = c.read(pactListViewModelProvider);
      expect(state.activeCount, 2);
      expect(state.doneCount, 1);
      expect(state.cancelledCount, 1);
    });

    test('toggleFilter deselects when multiple filters selected', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.active);
      final filters = c.read(pactListViewModelProvider).activeFilters;
      expect(filters, {PactStatus.completed, PactStatus.stopped});
    });

    test('toggleFilter can deselect all filters', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.active);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.completed);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.stopped);
      final filters = c.read(pactListViewModelProvider).activeFilters;
      expect(filters, isEmpty);
    });

    test('toggleFilter selects a deselected filter', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.completed);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.completed);
      final filters = c.read(pactListViewModelProvider).activeFilters;
      expect(filters, {PactStatus.active, PactStatus.completed, PactStatus.stopped});
    });

    test('filteredEntries respects activeFilters', () async {
      final c = _makeContainer(pacts: [
        _pact('a1', PactStatus.active),
        _pact('d1', PactStatus.completed),
        _pact('c1', PactStatus.stopped),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.completed);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.stopped);
      final filtered = c.read(pactListViewModelProvider).filteredEntries;
      expect(filtered.length, 1);
      expect(filtered.first.pact.id, 'a1');
    });

    test('archivedCount: counts archived entries', () async {
      final c = _makeContainer(pacts: [
        _pact('a1', PactStatus.active),
        _pact('c1', PactStatus.completed, archived: true),
        _pact('s1', PactStatus.stopped, archived: true),
        _pact('c2', PactStatus.completed),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      expect(c.read(pactListViewModelProvider).archivedCount, 2);
    });

    test('filteredEntries excludes archived when showArchived is false', () async {
      final c = _makeContainer(pacts: [
        _pact('c1', PactStatus.completed),
        _pact('c2', PactStatus.completed, archived: true),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final filtered = c.read(pactListViewModelProvider).filteredEntries;
      expect(filtered.length, 1);
      expect(filtered.first.pact.id, 'c1');
    });

    test('filteredEntries includes archived when showArchived is true', () async {
      final c = _makeContainer(pacts: [
        _pact('c1', PactStatus.completed),
        _pact('c2', PactStatus.completed, archived: true),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      c.read(pactListViewModelProvider.notifier).toggleArchived();
      final filtered = c.read(pactListViewModelProvider).filteredEntries;
      expect(filtered.length, 2);
    });

    test('toggleArchived toggles showArchived flag', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      expect(c.read(pactListViewModelProvider).showArchived, false);
      c.read(pactListViewModelProvider.notifier).toggleArchived();
      expect(c.read(pactListViewModelProvider).showArchived, true);
      c.read(pactListViewModelProvider.notifier).toggleArchived();
      expect(c.read(pactListViewModelProvider).showArchived, false);
    });

    test('sort: active → unarchived-completed → unarchived-stopped → archived-completed → archived-stopped', () async {
      final c = _makeContainer(pacts: [
        _pact('arch-stopped', PactStatus.stopped, archived: true),
        _pact('arch-completed', PactStatus.completed, archived: true),
        _pact('unarch-stopped', PactStatus.stopped),
        _pact('unarch-completed', PactStatus.completed),
        _pact('active', PactStatus.active),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      c.read(pactListViewModelProvider.notifier).toggleArchived();
      final ids = c.read(pactListViewModelProvider).filteredEntries.map((e) => e.pact.id).toList();
      expect(ids, ['active', 'unarch-completed', 'unarch-stopped', 'arch-completed', 'arch-stopped']);
    });

    test('concurrent load() calls: only one runs at a time', () async {
      // Arrange: a counting showup repository that lets us verify how many
      // times getShowupsForPact is invoked during concurrent load() calls.
      var callCount = 0;
      final slowShowupRepo = _SlowShowupRepository(onCall: () => callCount++);
      final c = ProviderContainer(overrides: [
        pactRepositoryProvider.overrideWithValue(InMemoryPactRepository([_pact('p1', PactStatus.active)])),
        showupRepositoryProvider.overrideWithValue(slowShowupRepo),
      ]);
      addTearDown(c.dispose);

      // Act: fire two load() calls without awaiting — the guard must prevent
      // the second call from entering the critical section while the first is
      // still awaiting.
      final f1 = c.read(pactListViewModelProvider.notifier).load();
      final f2 = c.read(pactListViewModelProvider.notifier).load();
      await Future.wait([f1, f2]);

      // Assert: getShowupsForPact was called exactly once (by the first load).
      expect(callCount, equals(1), reason: 'The in-progress guard must block the second concurrent load()');
    });
  });
}

// ---------------------------------------------------------------------------
// Test helper: a showup repository that records calls and can be made "slow"
// ---------------------------------------------------------------------------

class _SlowShowupRepository extends InMemoryShowupRepository {
  _SlowShowupRepository({required this.onCall}) : super([]);

  final void Function() onCall;

  @override
  Future<List<Showup>> getShowupsForPact(String pactId) async {
    onCall();
    // Yield to the event loop so a second concurrent load() can arrive before
    // this one completes — this is what makes the race condition observable.
    await Future<void>.delayed(Duration.zero);
    return super.getShowupsForPact(pactId);
  }
}

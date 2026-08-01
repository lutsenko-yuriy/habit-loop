import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
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

PactBreak _pactBreak(String id, String pactId, {DateTime? startDate, DateTime? plannedEndDate, DateTime? stoppedAt}) =>
    PactBreak(
      id: id,
      pactId: pactId,
      startDate: startDate ?? DateTime(2026, 1, 1),
      plannedEndDate: plannedEndDate,
      stoppedAt: stoppedAt,
      rationale: 'Recovering',
    );

ProviderContainer _makeContainer({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
  List<PactBreak> breaks = const [],
  DateTime? now,
}) {
  return ProviderContainer(overrides: [
    pactRepositoryProvider.overrideWithValue(InMemoryPactRepository(pacts)),
    showupRepositoryProvider.overrideWithValue(InMemoryShowupRepository(showups)),
    pactBreakRepositoryProvider.overrideWithValue(InMemoryPactBreakRepository(breaks)),
    if (now != null) pactListNowProvider.overrideWithValue(now),
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

    test('load: entry.onBreak is true for an active pact with an unresolved break', () async {
      final pact = _pact('p1', PactStatus.active);
      final c = _makeContainer(
        pacts: [pact],
        breaks: [_pactBreak('b1', 'p1')],
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.onBreak, isTrue);
    });

    test('load: entry.onBreak is false for an active pact with a break scheduled to start in the future (HAB-201)',
        () async {
      final pact = _pact('p1', PactStatus.active);
      final futureStart = DateTime.now().add(const Duration(days: 1));
      final c = _makeContainer(
        pacts: [pact],
        breaks: [_pactBreak('b1', 'p1', startDate: futureStart)],
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.onBreak, isFalse);
    });

    test('load: entry.onBreak is false for an active pact with a stopped break', () async {
      final pact = _pact('p1', PactStatus.active);
      final c = _makeContainer(
        pacts: [pact],
        breaks: [_pactBreak('b1', 'p1', stoppedAt: DateTime(2026, 1, 5))],
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.onBreak, isFalse);
    });

    test('load: onBreak respects an overridden pactListNowProvider, not real wall-clock time (HAB-211)', () async {
      // The break window (2099) is nowhere near real "now" — this only
      // passes if load() actually reads pactListNowProvider instead of
      // calling DateTime.now() directly.
      final pact = _pact('p1', PactStatus.active);
      final overriddenNow = DateTime(2099, 6, 16);
      final c = _makeContainer(
        pacts: [pact],
        breaks: [
          _pactBreak('b1', 'p1', startDate: DateTime(2099, 6, 10), plannedEndDate: DateTime(2099, 6, 20)),
        ],
        now: overriddenNow,
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.onBreak, isTrue);
    });

    test('load: entry.onBreak is false for an active pact with no breaks', () async {
      final pact = _pact('p1', PactStatus.active);
      final c = _makeContainer(pacts: [pact]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.onBreak, isFalse);
    });

    test('load: entry.onBreak is false for a non-active pact even with an unresolved break', () async {
      final pact = _pact('p1', PactStatus.stopped);
      final c = _makeContainer(
        pacts: [pact],
        breaks: [_pactBreak('b1', 'p1')],
      );
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.onBreak, isFalse);
    });

    test('toggleBreakFilter flips breakSelected', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      expect(c.read(pactListViewModelProvider).breakSelected, isFalse);
      c.read(pactListViewModelProvider.notifier).toggleBreakFilter();
      expect(c.read(pactListViewModelProvider).breakSelected, isTrue);
      c.read(pactListViewModelProvider.notifier).toggleBreakFilter();
      expect(c.read(pactListViewModelProvider).breakSelected, isFalse);
    });

    test('toggleFilter is unaffected by breakSelected — behaves like any other status toggle', () async {
      final c = _makeContainer(pacts: [
        _pact('onbreak', PactStatus.active),
        _pact('plain', PactStatus.active),
      ], breaks: [
        _pactBreak('b1', 'onbreak'),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();
      c.read(pactListViewModelProvider.notifier).toggleBreakFilter();
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.active);

      final state = c.read(pactListViewModelProvider);
      expect(state.breakSelected, isTrue, reason: 'Toggling a status chip must not touch the Break chip');
      expect(state.activeFilters, {PactStatus.completed, PactStatus.stopped});
    });

    // Truth table (A = Active chip, B = Break chip) for a plain active pact
    // and an on-break active pact, both otherwise identical:
    //   !A & !B → neither visible
    //    A & !B → only the plain active pact (on-break excluded)
    //   !A &  B → only the on-break pact
    //    A &  B → both
    // Break exclusively governs on-break pacts' visibility — Active alone
    // never surfaces them, matching how the pact list tile now visibly
    // distinguishes "Active" from "On break" (the badge added alongside).
    group('filteredEntries: Active/Break truth table', () {
      late ProviderContainer c;

      setUp(() async {
        c = _makeContainer(pacts: [
          _pact('plain', PactStatus.active),
          _pact('onbreak', PactStatus.active),
        ], breaks: [
          _pactBreak('b1', 'onbreak'),
        ]);
        await c.read(pactListViewModelProvider.notifier).load();
        // Start from a clean slate: both Active and Break deselected.
        c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.active);
      });

      tearDown(() => c.dispose());

      Set<String> visibleIds() => c.read(pactListViewModelProvider).filteredEntries.map((e) => e.pact.id).toSet();

      test('!A & !B → neither pact visible', () {
        expect(visibleIds(), isEmpty);
      });

      test('!A & B → only the on-break pact is visible', () {
        c.read(pactListViewModelProvider.notifier).toggleBreakFilter();
        expect(visibleIds(), {'onbreak'});
      });

      test('A & !B → only the plain active pact is visible, on-break excluded', () {
        c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.active);
        expect(visibleIds(), {'plain'});
      });

      test('A & B → both pacts are visible', () {
        c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.active);
        c.read(pactListViewModelProvider.notifier).toggleBreakFilter();
        expect(visibleIds(), {'plain', 'onbreak'});
      });
    });

    test('filteredEntries: Break has no effect on non-active pacts', () async {
      final c = _makeContainer(pacts: [
        _pact('stopped', PactStatus.stopped),
      ]);
      addTearDown(c.dispose);
      await c.read(pactListViewModelProvider.notifier).load();

      expect(c.read(pactListViewModelProvider).filteredEntries.map((e) => e.pact.id), ['stopped']);

      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.stopped);
      c.read(pactListViewModelProvider.notifier).toggleBreakFilter();

      expect(c.read(pactListViewModelProvider).filteredEntries, isEmpty,
          reason: 'Break only ever matches on-break pacts — it must not resurrect a deselected Stopped pact');
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

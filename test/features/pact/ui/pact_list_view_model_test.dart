import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

Pact _pact(String id, PactStatus status, {DateTime? endDate}) => Pact(
      id: id,
      habitName: 'Habit $id',
      startDate: DateTime(2026, 1, 1),
      endDate: endDate ?? DateTime(2026, 10, 1),
      showupDuration: const Duration(minutes: 15),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: status,
    );

Showup _showup(String id, String pactId, DateTime scheduledAt,
        {ShowupStatus status = ShowupStatus.pending}) =>
    Showup(
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
    pactListRepositoryProvider.overrideWithValue(InMemoryPactRepository(pacts)),
    pactListShowupRepositoryProvider
        .overrideWithValue(InMemoryShowupRepository(showups)),
  ]);
}

void main() {
  group('PactListViewModel', () {
    test('initial state: empty entries, all filters on, not loading', () {
      final c = _makeContainer();
      final state = c.read(pactListViewModelProvider);
      expect(state.entries, isEmpty);
      expect(state.isLoading, false);
      expect(state.activeFilters,
          {PactStatus.active, PactStatus.completed, PactStatus.stopped});
    });

    test('load with no pacts → empty entries', () async {
      final c = _makeContainer();
      await c.read(pactListViewModelProvider.notifier).load();
      expect(c.read(pactListViewModelProvider).entries, isEmpty);
    });

    test('load with active pact sets nextShowupAt to earliest pending showup', () async {
      final pact = _pact('p1', PactStatus.active);
      final future = DateTime(2026, 4, 10, 9);
      final earlier = DateTime(2026, 4, 5, 9);
      final c = _makeContainer(
        pacts: [pact],
        showups: [
          _showup('s1', 'p1', future),
          _showup('s2', 'p1', earlier),
        ],
      );
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
      await c.read(pactListViewModelProvider.notifier).load();
      final entry = c.read(pactListViewModelProvider).entries.first;
      expect(entry.nextShowupAt, isNull);
    });

    test('load with completed pact: nextShowupAt is null', () async {
      final pact = _pact('p1', PactStatus.completed);
      final c = _makeContainer(pacts: [pact]);
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
      await c.read(pactListViewModelProvider.notifier).load();
      final state = c.read(pactListViewModelProvider);
      expect(state.activeCount, 2);
      expect(state.doneCount, 1);
      expect(state.cancelledCount, 1);
    });

    test('toggleFilter deselects when multiple filters selected', () {
      final c = _makeContainer();
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.active);
      final filters = c.read(pactListViewModelProvider).activeFilters;
      expect(filters, {PactStatus.completed, PactStatus.stopped});
    });

    test('toggleFilter can deselect all filters', () {
      final c = _makeContainer();
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.active);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.completed);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.stopped);
      final filters = c.read(pactListViewModelProvider).activeFilters;
      expect(filters, isEmpty);
    });

    test('toggleFilter selects a deselected filter', () {
      final c = _makeContainer();
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
      await c.read(pactListViewModelProvider.notifier).load();
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.completed);
      c.read(pactListViewModelProvider.notifier).toggleFilter(PactStatus.stopped);
      final filtered = c.read(pactListViewModelProvider).filteredEntries;
      expect(filtered.length, 1);
      expect(filtered.first.pact.id, 'a1');
    });
  });
}

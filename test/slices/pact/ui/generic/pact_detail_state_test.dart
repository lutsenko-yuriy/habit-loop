import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_state.dart';

Pact _pact({required String id, required String habitName, String? predecessorPactId}) => Pact(
      id: id,
      habitName: habitName,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 7, 1),
      showupDuration: const Duration(minutes: 10),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.stopped,
      predecessorPactId: predecessorPactId,
    );

void main() {
  group('PactDetailState — chain fields (HAB-202)', () {
    test('predecessorPact defaults to null', () {
      const state = PactDetailState();
      expect(state.predecessorPact, isNull);
    });

    test('successorPact defaults to null', () {
      const state = PactDetailState();
      expect(state.successorPact, isNull);
    });

    test('predecessorPact and successorPact can be set at construction', () {
      final predecessor = _pact(id: 'root', habitName: 'Vibe coding');
      final successor = _pact(id: 'v3', habitName: 'Vibe coding (v3)');
      final state = PactDetailState(predecessorPact: predecessor, successorPact: successor);

      expect(state.predecessorPact, predecessor);
      expect(state.successorPact, successor);
    });

    test('copyWith updates predecessorPact and successorPact', () {
      const state = PactDetailState();
      final predecessor = _pact(id: 'root', habitName: 'Vibe coding');
      final successor = _pact(id: 'v3', habitName: 'Vibe coding (v3)');

      final updated = state.copyWith(predecessorPact: predecessor, successorPact: successor);

      expect(updated.predecessorPact, predecessor);
      expect(updated.successorPact, successor);
    });

    test('copyWith preserves predecessorPact and successorPact when not specified', () {
      final predecessor = _pact(id: 'root', habitName: 'Vibe coding');
      final successor = _pact(id: 'v3', habitName: 'Vibe coding (v3)');
      final state = PactDetailState(predecessorPact: predecessor, successorPact: successor);

      final updated = state.copyWith(isLoading: true);

      expect(updated.predecessorPact, predecessor);
      expect(updated.successorPact, successor);
    });

    test('copyWith clearPredecessorPact clears predecessorPact', () {
      final predecessor = _pact(id: 'root', habitName: 'Vibe coding');
      final state = PactDetailState(predecessorPact: predecessor);

      final updated = state.copyWith(clearPredecessorPact: true);

      expect(updated.predecessorPact, isNull);
    });

    test('copyWith clearSuccessorPact clears successorPact', () {
      final successor = _pact(id: 'v3', habitName: 'Vibe coding (v3)');
      final state = PactDetailState(successorPact: successor);

      final updated = state.copyWith(clearSuccessorPact: true);

      expect(updated.successorPact, isNull);
    });
  });
}

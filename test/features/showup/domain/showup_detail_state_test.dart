import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_detail_state.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

void main() {
  final sampleShowup = Showup(
    id: 's1',
    pactId: 'p1',
    scheduledAt: DateTime(2026, 4, 8, 8),
    duration: const Duration(minutes: 10),
    status: ShowupStatus.pending,
  );

  group('ShowupDetailState', () {
    test('default state has isLoading true and all others null/false', () {
      const state = ShowupDetailState();
      expect(state.isLoading, true);
      expect(state.showup, isNull);
      expect(state.habitName, isNull);
      expect(state.loadError, isNull);
      expect(state.isSaving, false);
      expect(state.saveError, isNull);
      expect(state.wasAutoFailed, false);
    });

    test('copyWith updates showup and habitName', () {
      const state = ShowupDetailState();
      final updated = state.copyWith(
        showup: sampleShowup,
        habitName: 'Meditate',
        isLoading: false,
      );
      expect(updated.showup, sampleShowup);
      expect(updated.habitName, 'Meditate');
      expect(updated.isLoading, false);
    });

    test('copyWith preserves unchanged fields', () {
      const state = ShowupDetailState(wasAutoFailed: true);
      final updated = state.copyWith(isLoading: false);
      expect(updated.wasAutoFailed, true);
      expect(updated.isLoading, false);
    });

    test('copyWith clearSaveError sets saveError to null', () {
      final state = ShowupDetailState(saveError: StateError('oops'));
      final cleared = state.copyWith(clearSaveError: true);
      expect(cleared.saveError, isNull);
    });

    test('copyWith clearLoadError sets loadError to null', () {
      final state = ShowupDetailState(loadError: StateError('load fail'));
      final cleared = state.copyWith(clearLoadError: true);
      expect(cleared.loadError, isNull);
    });

    test('copyWith with explicit null saveError leaves existing error intact', () {
      final error = StateError('original');
      final state = ShowupDetailState(saveError: error);
      final updated = state.copyWith(isLoading: false);
      expect(updated.saveError, error);
    });

    test('copyWith wasAutoFailed updates flag', () {
      const state = ShowupDetailState();
      final updated = state.copyWith(wasAutoFailed: true);
      expect(updated.wasAutoFailed, true);
    });
  });
}

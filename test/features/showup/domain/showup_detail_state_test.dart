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
      expect(state.markError, isNull);
      expect(state.noteError, isNull);
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

    test('copyWith clearMarkError sets markError to null', () {
      final state = ShowupDetailState(markError: StateError('mark failed'));
      final cleared = state.copyWith(clearMarkError: true);
      expect(cleared.markError, isNull);
    });

    test('copyWith clearNoteError sets noteError to null', () {
      final state = ShowupDetailState(noteError: StateError('note failed'));
      final cleared = state.copyWith(clearNoteError: true);
      expect(cleared.noteError, isNull);
    });

    test('copyWith clearLoadError sets loadError to null', () {
      final state = ShowupDetailState(loadError: StateError('load fail'));
      final cleared = state.copyWith(clearLoadError: true);
      expect(cleared.loadError, isNull);
    });

    test('markError and noteError are independent', () {
      final markErr = StateError('mark');
      final noteErr = StateError('note');
      final state = ShowupDetailState(markError: markErr, noteError: noteErr);
      // Clearing markError leaves noteError intact.
      final cleared = state.copyWith(clearMarkError: true);
      expect(cleared.markError, isNull);
      expect(cleared.noteError, noteErr);
    });

    test('copyWith wasAutoFailed updates flag', () {
      const state = ShowupDetailState();
      final updated = state.copyWith(wasAutoFailed: true);
      expect(updated.wasAutoFailed, true);
    });
  });
}

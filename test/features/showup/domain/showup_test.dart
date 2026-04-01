import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';

void main() {
  group('Showup', () {
    test('creates a pending showup', () {
      final showup = Showup(
        id: '1',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 29, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );

      expect(showup.id, '1');
      expect(showup.pactId, 'pact-1');
      expect(showup.scheduledAt, DateTime(2026, 3, 29, 7, 0));
      expect(showup.duration, const Duration(minutes: 10));
      expect(showup.status, ShowupStatus.pending);
      expect(showup.note, isNull);
    });

    test('creates a done showup with a note', () {
      final showup = Showup(
        id: '2',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 28, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
        note: 'Felt great today!',
      );

      expect(showup.status, ShowupStatus.done);
      expect(showup.note, 'Felt great today!');
    });

    test('creates a failed showup', () {
      final showup = Showup(
        id: '3',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 27, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.failed,
      );

      expect(showup.status, ShowupStatus.failed);
    });

    test('two showups with same fields are equal', () {
      final a = Showup(
        id: '1',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 29, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );
      final b = Showup(
        id: '1',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 29, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('copyWith', () {
    final base = Showup(
      id: '1',
      pactId: 'pact-1',
      scheduledAt: DateTime(2026, 3, 29, 7, 0),
      duration: const Duration(minutes: 10),
      status: ShowupStatus.pending,
    );

    test('updates status', () {
      final updated = base.copyWith(status: ShowupStatus.done);
      expect(updated.status, ShowupStatus.done);
      expect(updated.id, base.id);
    });

    test('updates note', () {
      final updated = base.copyWith(note: 'Great session');
      expect(updated.note, 'Great session');
      expect(updated.status, base.status);
    });

    test('clears note when clearNote is true', () {
      final withNote = base.copyWith(note: 'Some note');
      final cleared = withNote.copyWith(clearNote: true);
      expect(cleared.note, isNull);
    });

    test('unchanged fields are preserved', () {
      final updated = base.copyWith(status: ShowupStatus.failed);
      expect(updated.id, base.id);
      expect(updated.pactId, base.pactId);
      expect(updated.scheduledAt, base.scheduledAt);
      expect(updated.duration, base.duration);
    });
  });

  group('ShowupStatus', () {
    test('has three values', () {
      expect(ShowupStatus.values, hasLength(3));
      expect(ShowupStatus.values, contains(ShowupStatus.pending));
      expect(ShowupStatus.values, contains(ShowupStatus.done));
      expect(ShowupStatus.values, contains(ShowupStatus.failed));
    });
  });
}

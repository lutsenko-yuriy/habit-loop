import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';

void main() {
  group('PactBreak', () {
    test('creates a fixed-end break with required fields', () {
      final b = PactBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 1),
        plannedEndDate: DateTime(2026, 3, 10),
        rationale: 'Recovering from a cold',
      );

      expect(b.id, 'b1');
      expect(b.pactId, 'p1');
      expect(b.startDate, DateTime(2026, 3, 1));
      expect(b.plannedEndDate, DateTime(2026, 3, 10));
      expect(b.rationale, 'Recovering from a cold');
      expect(b.createdAt, isNull);
      expect(b.stoppedAt, isNull);
    });

    test('creates an open-ended break with a null plannedEndDate', () {
      final b = PactBreak(
        id: 'b2',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 1),
        rationale: 'Injury, unsure how long',
      );

      expect(b.plannedEndDate, isNull);
    });

    group('effectiveEnd', () {
      test('is plannedEndDate when not stopped', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        expect(b.effectiveEnd, DateTime(2026, 3, 10));
      });

      test('is null when open-ended and not stopped', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          rationale: 'r',
        );

        expect(b.effectiveEnd, isNull);
      });

      test('is stoppedAt when stopped, even if plannedEndDate is later', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 20),
          rationale: 'r',
          stoppedAt: DateTime(2026, 3, 5),
        );

        expect(b.effectiveEnd, DateTime(2026, 3, 5));
      });
    });

    group('contains', () {
      test('is true for a date inside a fixed window', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        expect(b.contains(DateTime(2026, 3, 5)), isTrue);
      });

      test('is true exactly on the start and end boundaries', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        expect(b.contains(DateTime(2026, 3, 1)), isTrue);
        expect(b.contains(DateTime(2026, 3, 10)), isTrue);
      });

      test('is false before the start date', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        expect(b.contains(DateTime(2026, 2, 28)), isFalse);
      });

      test('is false after a fixed end date', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        expect(b.contains(DateTime(2026, 3, 11)), isFalse);
      });

      test('is true arbitrarily far in the future when open-ended and not stopped', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          rationale: 'r',
        );

        expect(b.contains(DateTime(2030, 1, 1)), isTrue);
      });

      test('is false after stoppedAt fixes the window, even for a previously open-ended break', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          rationale: 'r',
          stoppedAt: DateTime(2026, 3, 5),
        );

        expect(b.contains(DateTime(2026, 3, 5)), isTrue);
        expect(b.contains(DateTime(2026, 3, 6)), isFalse);
      });
    });

    group('isActiveAt', () {
      test('mirrors contains for the given instant', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        expect(b.isActiveAt(DateTime(2026, 3, 5)), isTrue);
        expect(b.isActiveAt(DateTime(2026, 3, 11)), isFalse);
      });
    });

    group('isResolved', () {
      test('is false for an ongoing fixed-end break before its planned end', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        expect(b.isResolved(DateTime(2026, 3, 5)), isFalse);
      });

      test('is true once now is past a fixed planned end date, even without an explicit stop', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        expect(b.isResolved(DateTime(2026, 3, 11)), isTrue);
      });

      test('is false for an open-ended break that has not been stopped, no matter how far in the future', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          rationale: 'r',
        );

        expect(b.isResolved(DateTime(2030, 1, 1)), isFalse);
      });

      test('is true once stopped, regardless of now', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          rationale: 'r',
          stoppedAt: DateTime(2026, 3, 5),
        );

        expect(b.isResolved(DateTime(2026, 3, 5)), isTrue);
        expect(b.isResolved(DateTime(2026, 3, 6)), isTrue);
      });
    });

    group('stop', () {
      test('returns a new break with stoppedAt set, leaving the original unchanged', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 20),
          rationale: 'r',
        );

        final stopped = b.stop(DateTime(2026, 3, 5));

        expect(stopped.stoppedAt, DateTime(2026, 3, 5));
        expect(stopped.effectiveEnd, DateTime(2026, 3, 5));
        expect(b.stoppedAt, isNull);
      });
    });

    group('copyWith', () {
      test('preserves identity fields and overrides only what is passed', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
          createdAt: DateTime(2026, 3, 1),
        );

        final updated = b.copyWith(rationale: 'updated rationale');

        expect(updated.id, 'b1');
        expect(updated.pactId, 'p1');
        expect(updated.startDate, DateTime(2026, 3, 1));
        expect(updated.plannedEndDate, DateTime(2026, 3, 10));
        expect(updated.createdAt, DateTime(2026, 3, 1));
        expect(updated.rationale, 'updated rationale');
      });

      test('clearPlannedEndDate turns a fixed-end break into an open-ended one', () {
        final b = PactBreak(
          id: 'b1',
          pactId: 'p1',
          startDate: DateTime(2026, 3, 1),
          plannedEndDate: DateTime(2026, 3, 10),
          rationale: 'r',
        );

        final updated = b.copyWith(clearPlannedEndDate: true);

        expect(updated.plannedEndDate, isNull);
      });
    });

    test('two breaks with same fields are equal', () {
      final a = PactBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 1),
        plannedEndDate: DateTime(2026, 3, 10),
        rationale: 'r',
      );
      final b = PactBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 1),
        plannedEndDate: DateTime(2026, 3, 10),
        rationale: 'r',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('breaks with different stoppedAt are not equal', () {
      final a = PactBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 1),
        rationale: 'r',
        stoppedAt: DateTime(2026, 3, 5),
      );
      final b = PactBreak(
        id: 'b1',
        pactId: 'p1',
        startDate: DateTime(2026, 3, 1),
        rationale: 'r',
      );

      expect(a, isNot(equals(b)));
    });
  });
}

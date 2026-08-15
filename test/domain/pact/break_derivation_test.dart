import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/break_derivation.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_generator.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

final _pact = Pact(
  id: 'pact-1',
  habitName: 'Meditate',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 12, 1),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  reminderOffset: const Duration(minutes: 15),
);

Showup _showup(ShowupStatus status, DateTime scheduledAt) {
  return Showup(
    id: 'showup-1',
    pactId: 'pact-1',
    scheduledAt: scheduledAt,
    duration: const Duration(minutes: 10),
    status: status,
  );
}

PactBreak _pactBreak({
  String id = 'break-1',
  required DateTime startDate,
  DateTime? plannedEndDate,
  DateTime? stoppedAt,
}) {
  return PactBreak(
    id: id,
    pactId: 'pact-1',
    startDate: startDate,
    rationale: 'Recovering',
    plannedEndDate: plannedEndDate,
    stoppedAt: stoppedAt,
  );
}

void main() {
  group('BreakDerivation.isShowupOnBreak', () {
    test('false when there are no breaks', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2026, 3, 5));
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: []), isFalse);
    });

    test('true for a pending showup inside a fixed-end break window', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2026, 3, 5));
      final breaks = [_pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10))];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isTrue);
    });

    test('false for a pending showup before the break starts', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2026, 2, 28));
      final breaks = [_pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10))];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isFalse);
    });

    test('false for a pending showup after the break ends', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2026, 3, 11));
      final breaks = [_pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10))];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isFalse);
    });

    test('true for a pending showup on an open-ended ("until pact ends") break', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2027, 1, 1));
      final breaks = [_pactBreak(startDate: DateTime(2026, 3, 1))];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isTrue);
    });

    test('done showup inside a break window is not on break — explicit mark overrides', () {
      final showup = _showup(ShowupStatus.done, DateTime(2026, 3, 5));
      final breaks = [_pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10))];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isFalse);
    });

    test('failed showup inside a break window is not on break — explicit mark overrides', () {
      final showup = _showup(ShowupStatus.failed, DateTime(2026, 3, 5));
      final breaks = [_pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10))];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isFalse);
    });

    test('true when showup falls inside the second of multiple breaks', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2026, 5, 5));
      final breaks = [
        _pactBreak(id: 'break-1', startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10)),
        _pactBreak(id: 'break-2', startDate: DateTime(2026, 5, 1), plannedEndDate: DateTime(2026, 5, 10)),
      ];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isTrue);
    });

    test('a stopped break keeps showups already inside its fixed window on-break', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2026, 3, 3));
      final breaks = [
        _pactBreak(
            startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10), stoppedAt: DateTime(2026, 3, 4)),
      ];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isTrue);
    });

    test('a stopped break excludes showups after the stop date', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2026, 3, 6));
      final breaks = [
        _pactBreak(
            startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10), stoppedAt: DateTime(2026, 3, 4)),
      ];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isFalse);
    });
  });

  group('BreakDerivation.firstShowupAfterBreak', () {
    test('returns the actual Showup, not just its id', () {
      final b = _pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 5));

      final showup = BreakDerivation.firstShowupAfterBreak(_pact, b);

      expect(showup, isNotNull);
      expect(showup!.scheduledAt, DateTime(2026, 3, 6, 8));
      expect(showup.pactId, _pact.id);
    });

    test('null for an open-ended break', () {
      final b = _pactBreak(startDate: DateTime(2026, 3, 1));
      expect(BreakDerivation.firstShowupAfterBreak(_pact, b), isNull);
    });
  });

  group('BreakDerivation.welcomeBackShowupIds', () {
    test('returns the id of the first daily showup after a fixed-end break', () {
      final b = _pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 5));

      final ids = BreakDerivation.welcomeBackShowupIds(_pact, [b]);

      // First daily 8am occurrence strictly after 3/5 23:59:59.999 is 3/6 08:00.
      final expected = ShowupGenerator.generateWindow(_pact,
              from: DateTime(2026, 3, 6, 8), to: DateTime(2026, 3, 6, 8).add(const Duration(minutes: 1)))
          .first
          .id;
      expect(ids, {expected});
    });

    test('empty for an open-ended break, even though it has a start date', () {
      final b = _pactBreak(startDate: DateTime(2026, 3, 1));

      expect(BreakDerivation.welcomeBackShowupIds(_pact, [b]), isEmpty);
    });

    test('empty when the break was resumed early (before its planned end)', () {
      final b = _pactBreak(
        startDate: DateTime(2026, 3, 1),
        plannedEndDate: DateTime(2026, 3, 5),
        stoppedAt: DateTime(2026, 3, 3, 12),
      );

      expect(BreakDerivation.welcomeBackShowupIds(_pact, [b]), isEmpty);
    });

    test('unchanged when the break was resumed at/after its planned end (not early)', () {
      final b = _pactBreak(
        startDate: DateTime(2026, 3, 1),
        plannedEndDate: DateTime(2026, 3, 5),
        stoppedAt: DateTime(2026, 3, 6, 9),
      );

      final ids = BreakDerivation.welcomeBackShowupIds(_pact, [b]);

      final expected = ShowupGenerator.generateWindow(_pact,
              from: DateTime(2026, 3, 6, 8), to: DateTime(2026, 3, 6, 8).add(const Duration(minutes: 1)))
          .first
          .id;
      expect(ids, {expected});
    });

    test('combines target ids across multiple eligible breaks', () {
      final b1 = _pactBreak(id: 'b1', startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 5));
      final b2 = _pactBreak(
        id: 'b2',
        startDate: DateTime(2026, 6, 1),
        plannedEndDate: DateTime(2026, 6, 5),
        stoppedAt: DateTime(2026, 6, 6, 9),
      );

      final ids = BreakDerivation.welcomeBackShowupIds(_pact, [b1, b2]);

      expect(ids, {
        ShowupGenerator.generateWindow(_pact,
                from: DateTime(2026, 3, 6, 8), to: DateTime(2026, 3, 6, 8).add(const Duration(minutes: 1)))
            .first
            .id,
        ShowupGenerator.generateWindow(_pact,
                from: DateTime(2026, 6, 6, 8), to: DateTime(2026, 6, 6, 8).add(const Duration(minutes: 1)))
            .first
            .id,
      });
    });

    test('empty when there are no breaks', () {
      expect(BreakDerivation.welcomeBackShowupIds(_pact, []), isEmpty);
    });
  });
}

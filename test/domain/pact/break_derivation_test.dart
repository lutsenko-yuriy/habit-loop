import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/break_derivation.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

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
        _pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10), stoppedAt: DateTime(2026, 3, 4)),
      ];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isTrue);
    });

    test('a stopped break excludes showups after the stop date', () {
      final showup = _showup(ShowupStatus.pending, DateTime(2026, 3, 6));
      final breaks = [
        _pactBreak(startDate: DateTime(2026, 3, 1), plannedEndDate: DateTime(2026, 3, 10), stoppedAt: DateTime(2026, 3, 4)),
      ];
      expect(BreakDerivation.isShowupOnBreak(showup: showup, breaks: breaks), isFalse);
    });
  });
}

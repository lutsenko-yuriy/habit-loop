import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/reminder/application/reconciliation_throttle.dart';

void main() {
  group('ReconciliationThrottle', () {
    test('tryStart returns true on first call', () {
      final throttle = ReconciliationThrottle();
      expect(throttle.tryStart(DateTime(2026, 1, 1, 12)), isTrue);
    });

    test('tryStart returns false while a run is in progress, regardless of elapsed time', () {
      final throttle = ReconciliationThrottle(minInterval: const Duration(seconds: 30));
      expect(throttle.tryStart(DateTime(2026, 1, 1, 12)), isTrue);

      expect(throttle.tryStart(DateTime(2026, 1, 1, 12, 1)), isFalse);
    });

    test('tryStart returns false before minInterval has elapsed since the last run started', () {
      final throttle = ReconciliationThrottle(minInterval: const Duration(seconds: 30));
      final start = DateTime(2026, 1, 1, 12);
      expect(throttle.tryStart(start), isTrue);
      throttle.finish();

      expect(throttle.tryStart(start.add(const Duration(seconds: 29))), isFalse);
    });

    test('tryStart returns true once minInterval has elapsed since the last run started', () {
      final throttle = ReconciliationThrottle(minInterval: const Duration(seconds: 30));
      final start = DateTime(2026, 1, 1, 12);
      expect(throttle.tryStart(start), isTrue);
      throttle.finish();

      expect(throttle.tryStart(start.add(const Duration(seconds: 30))), isTrue);
    });

    test('finish allows a new run to start immediately if minInterval has already elapsed', () {
      final throttle = ReconciliationThrottle(minInterval: Duration.zero);
      final start = DateTime(2026, 1, 1, 12);
      expect(throttle.tryStart(start), isTrue);
      throttle.finish();

      expect(throttle.tryStart(start), isTrue);
    });
  });
}

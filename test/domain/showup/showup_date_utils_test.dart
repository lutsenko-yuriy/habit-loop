import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup_date_utils.dart';

void main() {
  group('ShowupDateUtils.startOfDay', () {
    test('strips hours, minutes, seconds', () {
      expect(ShowupDateUtils.startOfDay(DateTime(2026, 3, 15, 14, 30, 45)), DateTime(2026, 3, 15));
    });

    test('returns same value for a date already at midnight', () {
      expect(ShowupDateUtils.startOfDay(DateTime(2026, 6, 1)), DateTime(2026, 6, 1));
    });
  });

  group('ShowupDateUtils.endOfDay', () {
    test('returns start of the next day', () {
      expect(ShowupDateUtils.endOfDay(DateTime(2026, 3, 15, 14, 30)), DateTime(2026, 3, 16));
    });

    test('handles end-of-month boundary', () {
      expect(ShowupDateUtils.endOfDay(DateTime(2026, 1, 31)), DateTime(2026, 2, 1));
    });

    test('handles end-of-year boundary', () {
      expect(ShowupDateUtils.endOfDay(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
    });

    test('handles February 28 in a non-leap year', () {
      expect(ShowupDateUtils.endOfDay(DateTime(2026, 2, 28)), DateTime(2026, 3, 1));
    });

    test('handles February 28 in a leap year (advances to Feb 29)', () {
      expect(ShowupDateUtils.endOfDay(DateTime(2024, 2, 28)), DateTime(2024, 2, 29));
    });

    test('uses calendar arithmetic — result is unaffected by input time component', () {
      final withTime = ShowupDateUtils.endOfDay(DateTime(2026, 6, 15, 23, 59, 59));
      final withoutTime = ShowupDateUtils.endOfDay(DateTime(2026, 6, 15));
      expect(withTime, withoutTime);
    });
  });
}
